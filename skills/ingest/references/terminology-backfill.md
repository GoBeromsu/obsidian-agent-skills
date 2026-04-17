# Terminology Backfill — Stage 4 (detailed reference)

SKILL.md delegates Stage 4 detail here. Read this before executing Stage 4.

## Trigger

Stage 4 is triggered by the Stage 2 agent immediately after receiving APPROVE from
Stage 3. Stage 2 spawns a fresh Stage 4 orchestrator agent via the Task tool (separate
context — not Stage 1 or Stage 3 carrying over). Stage 1 has already exited after
spawning Stage 2.

## Inputs

All three must be passed explicitly in the Stage 4 spawn payload:

  sidecar_path   — absolute path to the _terminology_hits.json sidecar
                   e.g.: /tmp/ingest-<raw_note_stem>-<yyyymmdd>/<raw_note_stem>_terminology_hits.json
  processed_path — absolute path to the processed note
  raw_path       — absolute path to the raw note

sidecar_path is NOT derived from raw_path — it is passed directly from Stage 2, which
received it from Stage 1's spawn payload.

## Fan-out Rules

### 1. Read merged_hits from sidecar

Open the sidecar at sidecar_path and read the merged_hits array.

### 2. Skip-threshold filter

Remove entries where ALL of the following are true (logical AND — BOTH must be true
to skip; if EITHER is false, keep the entry):

  Condition A: stage2_hits.mentions_in_processed == 1
  Condition B: processed_line_count < 100

Read processed_line_count: wc -l "<processed_path>"

IMPORTANT: evaluate against stage2_hits.mentions_in_processed, NOT
merged_hits.mentions_in_processed. The merged count includes raw-stage occurrences
which must not influence the Stage 4 skip decision (see terminology-substitute.md
§Skip Criteria for the full rationale).

### 3. Source-idempotency pre-check

Before spawning each terminology subagent, check whether the processed note is already
cited in the canonical term note:

  grep -l "<processed_note_filename_stem>" \
    "50. AI/02 Terminologies/<TARGET_TERM>.md"

  <processed_note_filename_stem> = filename of processed note without .md extension
  Example: "부잣집 자제들이 가진 진짜 무기" for
           "50. AI/05 Videos/부잣집 자제들이 가진 진짜 무기.md"

If the stem is found in the canonical note:
  - Mark: TERM_RESULT: term="<TERM>" status=skipped reason="source already cited"
  - Do NOT spawn a subagent for this term.
  - This prevents duplicate Literature Review entries on repeat ingests of the same source.

If the canonical note does not exist yet (new term): proceed to spawn.

### 4. Hard cap

If len(filtered_hits_after_steps_2_3) > 24:
  - Sort remaining hits by stage2_hits.mentions_in_processed descending.
  - Keep top 24.
  - Move remainder to skipped_over_cap in the sidecar.
  - Surface the skipped list to the user before proceeding:
    "Hard cap reached: <N> terms skipped (over cap 24): <list>"

### 5. Spawn subagents in batches of <= 8 (parallelism cap = 8)

For each term in the filtered list:
  a. Read processed_path and extract the paragraph(s) where the term appears.
  b. Spawn a fresh agent:

       Spawn a fresh agent:
         - Role: terminology backfill subagent for ingest Stage 4
         - Invoke: Skill("terminology") for term "<TERM_NAME>"
         - source_context: <extracted paragraph(s) from processed_path where TERM appears>
         - source_note_path: <processed_path>
         - Expected output: TERM_RESULT: term="<TERM>" status=completed|skipped|failed reason="..."

  Do NOT dump the full processed note into the spawn payload — pass only the
  surrounding paragraph(s) as source_context. The subagent will Read the note if needed.

  Subagent contract (MUST appear in every spawn prompt):
    - Invoke the terminology skill end-to-end (Step 1–4).
    - Do NOT call `qmd update`. The orchestrator runs a single batched qmd update
      after all batches complete. See §qmd Update Policy below.

### 6. After each batch

Update completed_terms in the sidecar with the terms that returned status=completed.
Overwrite the sidecar file after each batch.

### 7. Failure handling

If a subagent returns status=failed:
  - Log: TERM_RESULT: term="<TERM>" status=failed reason="<reason>"
  - Continue remaining batches — do NOT abort.
  - Collect all failures for the final summary.

## qmd Update Policy

Single batched update, owned by the orchestrator. Subagents MUST suppress their
terminology-skill Step 5 qmd update call. After all batches complete, the Stage 4
orchestrator runs exactly one `qmd update` covering every refreshed note. Rationale:

  - avoids write contention from <= 8 parallel writers
  - produces one atomic index refresh per ingest
  - simpler failure semantics (one retry target, not N)

If a subagent's skill flow nonetheless triggers an internal qmd update, accept it as
idempotent noise — the orchestrator's final call is still required and authoritative.

## Post-batch Cleanup

After ALL batches complete:

1. Compute final counts:
     N_refreshed = len(completed_terms)
     M_threshold = terms skipped by step 2 filter
     K_cited     = terms skipped by source-idempotency check (step 3)
     L_cap       = len(skipped_over_cap)
     P_failed    = terms with status=failed

2. Run `qmd update` exactly once (orchestrator call). Required regardless of whether
   any subagent auto-called it. This is the single authoritative index refresh.

3. Delete the sidecar directory (/tmp/ingest-<stem>-<yyyymmdd>/) ONLY if P_failed == 0.
   If P_failed > 0: leave directory for resumption; include path in user summary.

4. Surface summary to user:
     Stage 4 complete: <N> refreshed, <M> skipped (threshold), <K> skipped (source
     already cited), <L> skipped (over cap), <P> failed.
     [If P > 0: Sidecar retained at <sidecar_path> for resumption.]

## Resumption Protocol

If Stage 4 is re-run after partial failure:
  1. Read the existing sidecar at /tmp/ingest-<stem>-<yyyymmdd>/ if it exists.
  2. Skip all terms in completed_terms.
  3. Resume from the first term NOT in completed_terms.
  4. Re-apply source-idempotency pre-check (step 3) — the canonical note may have been
     updated by the completed batch.
  5. Do NOT re-spawn for completed terms.

If the /tmp/ directory was lost (e.g., machine reboot): re-run from step 1 using the
processed note. The source-idempotency check in step 3 prevents duplicate LR entries
for terms already processed in the previous run.

## Corpus Quality Note

Each terminology subagent runs the full 5-step terminology skill pipeline, which
overwrites the canonical term note via the Write tool. Over many ingests, this
increases corpus coverage but may reduce per-entry editorial precision — a human would
apply editorial judgment that an automated subagent approximates via the terminology
skill's quality heuristics. The skip threshold, hard cap, and source-idempotency guard
are the primary quality controls. Post-iteration-2 telemetry should assess whether a
human-review gate is warranted for Stage 4 outputs on high-frequency terms.

## Skip Threshold Reference

  Condition: stage2_hits.mentions_in_processed == 1 AND processed_line_count < 100
  Logic:     AND (BOTH conditions must be true to skip)
  Variable:  stage2_hits (NOT merged_hits)

## Verification Checklist

- [ ] sidecar_path received as explicit input (not derived from raw_path)
- [ ] merged_hits read from sidecar
- [ ] Skip threshold applied using stage2_hits.mentions_in_processed with AND logic
- [ ] Source-idempotency pre-check performed for every term before spawn
- [ ] Hard cap of 24 applied if needed; skipped_over_cap surfaced to user
- [ ] Subagents spawned in batches of <= 8
- [ ] completed_terms updated in sidecar after each successful batch
- [ ] Failure handling: continue on single failure; collect for summary
- [ ] Subagent spawn prompts explicitly instruct "do NOT call qmd update"
- [ ] Orchestrator ran exactly one `qmd update` after all batches completed
- [ ] Sidecar directory deleted on P_failed == 0; retained otherwise
- [ ] User summary surfaced with all five counts
