---
name: ingest
description: >
  4-stage pipeline with terminology graph integration: Stage 1 saves raw (exits after spawning Stage 2), Stage 2 rewrites to 「W를 찾아서」-grade prose and spawns Stage 4 on APPROVE, Stage 3 audits transcript coverage, Stage 4 fans out /terminology subagents to refresh the corpus. Triggers: "ingest", "영상 저장", "아티클 저장", "노트 만들어줘".
---

# ingest

## Overview

A 4-stage pipeline that turns one URL into a vault note at 「W를 찾아서」 quality:

1. **Stage 1 — Raw** (this agent): defuddle → resonance (공명) → terminology substitute (raw Transcript/Content only) → save raw → spawn Stage 2 → **exit**
2. **Stage 2 — Process** (fresh agent, Task tool): rewrite → mermaid → structural DoD self-check → terminology substitute (full processed body) → save → spawn Stage 3; on APPROVE spawn Stage 4
3. **Stage 3 — Review** (fresh agent, read-only): transcript coverage audit → APPROVE / ITERATE / REJECT
4. **Stage 4 — Terminology backfill** (fresh orchestrator, spawned by Stage 2 after APPROVE): source-idempotency check → fan-out parallel `/terminology` subagents → `50. AI/02 Terminologies/`

**SSOT chain.** Raw note holds the web URL (`source_url:`). Processed note holds a full-path wikilink to the raw note (e.g., `source: "[[80. References/05 Videos/TITLE|TITLE]]"`). The full path is required because raw and processed notes share the same filename stem — a bare `[[TITLE]]` would resolve ambiguously. Reviewer reads both. Raw is immutable; processed is regenerable.

**Why 3 stages?** Stage 1 and 2 run in separate contexts so the rewriter gets a focused prompt, not a conversation history. Stage 3 is a fresh agent so the reviewer cannot self-approve its own draft.

## Vault Access

Use the `obsidian-cli` skill for all note creation, edit, search, and property mutation inside the Ataraxia vault. Do not shell out to raw `cat`/`sed` on vault paths. See the `obsidian-cli` SKILL.md for the command surface and required preconditions (Obsidian must be running).

## When to Use

- User provides a YouTube URL or web article URL to capture
- User says "ingest", "영상 저장", "아티클 저장", "노트 만들어줘"

Do NOT use for:
- Bulk channel processing (`channel-ingest`)
- Lightweight summaries
- Wiki concept synthesis (separate scope)

---

## Stage 1 — Raw (this agent)

Follow `references/stage1-raw.md` in detail. Summary:

1. Detect URL type (video vs article)
2. Interview the user briefly (1-3 exchanges) for resonance (공명)
3. Security-validate the URL (ingest-owned), then invoke `/defuddle`: JSON mode for articles, markdown mode (`--md -o /tmp/ingest-defuddle-output.md`) for video transcripts; delete the temp file after reading
4. Load the correct template from `assets/`:
   - Video: `assets/video-raw.template.md`
   - Article: `assets/article-raw.template.md`
5. Fill the template. Resolve author/channel against `70. Collections/01 People/` and `50. AI/03 People/`. Never write a broken wikilink.
6. Sanitize the filename (allowlist `[A-Za-z0-9가-힣 ._-]`, ≤ 60 chars, assert final path starts with the expected base dir)
7. Save:
   - Video → `80. References/05 Videos/TITLE.md` (`status: todo`)
   - Article → `80. References/04 Articles/TITLE.md` (`status: todo`)
8. **Spawn Stage 2** (see directive below)

### Stage 2 spawn directive

After saving the raw note, use the Task tool to spawn a fresh agent. Hand over the minimal context; do NOT dump the raw content into the prompt (the fresh agent will Read it).

```
Spawn a fresh agent with:
  - Role: Stage 2 processor for the ingest skill.
  - Read these files first:
      * <skill>/references/stage2-process.md
      * <skill>/references/golden-patterns.md
      * <skill>/assets/video-processed.template.md   (or article-processed)
  - Task: Read raw_path, rewrite into a 문어체 (formal written Korean) processed note, save to 50. AI/.
  - Inputs:
      raw_path: /absolute/path/to/raw.md
      content_type: video | article
      user_intent: <the resonance text from Stage 1>
      iteration: 1
  - When done, spawn the Stage 3 reviewer per <skill>/references/stage2-process.md Step 8.
```

---

## Stage 2 — Process (spawned agent)

The spawned agent reads `references/stage2-process.md` and `references/golden-patterns.md`. It is bound by every-sentence-preservation, chapter floors, per-chapter mermaid, 5+ validated wikilinks, and TL;DR callout shape. It uses `assets/{video,article}-processed.template.md`. It writes to `50. AI/05 Videos/` or `50. AI/06 Articles/` with `status: done` and `source:` as a full-path wikilink to the raw note (`"[[80. References/05 Videos/TITLE|TITLE]]"` for video, `"[[80. References/04 Articles/TITLE|TITLE]]"` for article).

When the processed note is saved, Stage 2 spawns Stage 3.

---

## Stage 3 — Review (spawned agent, read-only)

Spawn a fresh agent using the Task tool. The agent reads `agents/reviewer.md` (Claude Code) or `agents/reviewer.yaml` (Codex) and evaluates the processed note against `references/golden-patterns.md`.

### Stage 3 spawn directive

```
Spawn a fresh read-only agent with:
  - Role: ingest-reviewer (read `<skill>/agents/reviewer.md`).
  - Tools: Read, Grep, Glob, Bash  (NO Write, NO Edit)
  - Inputs:
      processed_path: /absolute/path/to/processed.md
      raw_path: /absolute/path/to/raw.md
      iteration: 1 | 2 | 3
  - Expected output: VERDICT (APPROVE|ITERATE|REJECT) + EVIDENCE block + FEEDBACK list.
```

### Handling the verdict

- `APPROVE` → Stage 2 spawns Stage 4 (terminology backfill)
- `ITERATE` and `iteration < 3` → re-spawn Stage 2 with the reviewer's FEEDBACK appended; increment iteration
- `ITERATE` at `iteration == 3` or `REJECT` → surface the verdict + FEEDBACK + last draft to the user; do NOT silently retry

## Stage 4 — Terminology Backfill (spawned by Stage 2 after Stage 3 APPROVE)

Stage 4 is triggered by Stage 2 on receiving APPROVE from Stage 3. Stage 2 spawns a
fresh Stage 4 orchestrator via the Task tool. Stage 1 has already exited.

Follow `references/terminology-backfill.md` in full. Summary:

1. Read sidecar from sidecar_path (passed explicitly — do NOT derive from raw_path)
2. Skip-threshold filter (logical AND; evaluate stage2_hits.mentions_in_processed only)
3. Source-idempotency pre-check (grep canonical term note for processed note filename stem)
4. Hard cap: max 24 hits sorted by stage2_hits.mentions_in_processed desc
5. Spawn batches of <= 8 parallel /terminology subagents (one subagent per term)
6. Subagents MUST NOT call qmd update; orchestrator runs ONE qmd update after all batches
7. Delete /tmp/ingest-<stem>-<yyyymmdd>/ on full success (P_failed == 0)
8. Surface summary: N refreshed, M threshold, K cited, L cap, P failed

### Stage 4 spawn directive

  Spawn a fresh agent:
    - Role: Stage 4 terminology backfill orchestrator for the ingest skill
    - Read: <skill>/references/terminology-backfill.md
    - Task: Execute Stage 4 fan-out per terminology-backfill.md
    - Inputs:
        sidecar_path:   <explicit absolute path>
                        e.g. /tmp/ingest-<stem>-<yyyymmdd>/<stem>_terminology_hits.json
        processed_path: /absolute/path/to/processed.md
        raw_path:       /absolute/path/to/raw.md

## Setup Layout

```
ingest/
├── SKILL.md                               (this file)
├── assets/
│   ├── video-raw.template.md
│   ├── video-processed.template.md
│   ├── article-raw.template.md
│   └── article-processed.template.md
├── references/
│   ├── golden-patterns.md
│   ├── stage1-raw.md
│   ├── stage2-process.md
│   ├── terminology-substitute.md     (shared subroutine — Stage 1 + 2)
│   └── terminology-backfill.md       (Stage 4 fan-out rules)
└── agents/
    ├── reviewer.md                        (Claude Code subagent)
    └── reviewer.yaml                      (Codex equivalent)
```

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "Stage 1 and 2 can share the same agent to save tokens." | Self-review bias destroys the reviewer's independence. Fresh context per stage is the point. |
| "I'll inline the frontmatter in SKILL.md for speed." | Templates drift; frontmatter SSOT is `assets/`. Read the template, don't reinvent. |
| "A shorter summary is cleaner." | This is a REWRITE workflow. Every sentence must appear. See `golden-patterns.md`. |
| "2-3 chapters is enough for a long lecture." | Chapter floors exist to prevent under-segmentation. See the tables in `golden-patterns.md`. |
| "The reviewer is too strict — skip Stage 3." | The reviewer is the quality gate. Without it, the pipeline silently regresses. |

## Red Flags

- Stage 1 and Stage 2 executed in the same agent context
- `source:` field in processed note is a URL or bare `[[TITLE]]` instead of a full-path `[[80. References/{05 Videos|04 Articles}/TITLE|TITLE]]` wikilink
- Reviewer verdict ignored or Stage 3 skipped
- Re-spawn loop runs more than 3 iterations

## Verification

- [ ] Raw note saved at `80. References/{05 Videos|04 Articles}/TITLE.md` with `status: todo`
- [ ] Raw has non-empty `## 공명`
- [ ] Stage 2 spawned via Task tool (not continued in same context)
- [ ] Processed note saved at `50. AI/{05 Videos|06 Articles}/TITLE.md` with `status: done`
- [ ] Processed `source:` is a full-path wikilink (`"[[80. References/05 Videos/TITLE|TITLE]]"` or `"[[80. References/04 Articles/TITLE|TITLE]]"`) that resolves to the raw note
- [ ] Stage 3 reviewer verdict recorded and followed
- [ ] If ITERATE, re-spawn happened with FEEDBACK; if ≥3 iterations, user was surfaced
- [ ] Stage 1 exits after spawning Stage 2 (does NOT orchestrate Stage 4)
- [ ] Terminology substitute applied in Stage 1 (Transcript/Content only) and Stage 2 (full body, after frontmatter)
- [ ] /tmp/ingest-<stem>-<yyyymmdd>/ created by Stage 1; updated by Stage 2; deleted after Stage 4
- [ ] sidecar_path passed explicitly in Stage 1→2 and Stage 2→Stage 4 spawn payloads
- [ ] Stage 4 spawned by Stage 2 after Stage 3 APPROVE; uses fresh orchestrator context
- [ ] Stage 4 summary surfaced to user
