# Terminology Substitution — Shared Subroutine

Called from Stage 1 (Step 4b) and Stage 2 (Step 5b). Both callers follow this spec
identically. Do NOT duplicate this logic — read this file and apply the algorithm.

## Input Scope

Apply substitution to body text ONLY. Strip the frontmatter fences first:
- Identify the opening `---` on line 1 and the closing `---` that ends the YAML block.
- Apply substitution only to lines AFTER the closing `---` fence.
- Never insert wikilinks into frontmatter field values.

Additionally:
- Stage 1 applies substitution to the `## Transcript` or `## Content` section only
  (not to `## 공명` or any other section).
- Stage 2 applies substitution to the entire post-frontmatter body.

## Algorithm

### Step 1 — Build term index from `50. AI/02 Terminologies/`

For each `.md` file in `50. AI/02 Terminologies/`:
  a. Strip `.md` extension; strip `(ACRONYM)` parenthetical suffix to get the display stem.
  b. Read frontmatter `aliases` — add Korean variants, acronyms, and alternate English
     spellings to the index.

Index structure (lookup key → canonical note title):
  "deep learning"  → "Deep Learning (DL)"
  "딥러닝"           → "Deep Learning (DL)"
  "dl"             → "Deep Learning (DL)"
  "transformer"    → "Transformer"
  "트랜스포머"         → "Transformer"

### Step 2 — Apply per-section substitution

Split the in-scope body on `##` headings; process each section independently.

Within each section, for the FIRST occurrence of each matched term:
  - Display text matches canonical stem exactly → `[[Canonical|display]]`
  - Display text is an alias → `[[Canonical|alias]]`

All subsequent occurrences of the same term in the same section: leave as plain text.

### Step 3 — Matching rules

- English: case-insensitive (`transformer` matches `TRANSFORMER`, `Transformer`)
- Korean: exact match only — do not fuzzy-match Korean characters
- Minimum term length: 2 characters — skip single-character terms
- Whole-word boundary: do not match "AI" inside "RAIL" or "training" inside "retraining"

### Step 4 — Stopwords

Skip these terms even if a canonical note exists:

  데이터, 기술, 시스템, 모델 (generic), 문제 (generic), AI (standalone generic),
  방법, 방식, 과정, 결과, 내용, 경우

Extensible — add new entries between these markers:
  <!-- stopwords-extend -->
  <!-- end-stopwords-extend -->

### Step 5 — Build hits list

After substitution, build one entry per matched term:

  {
    "term": "Deep Learning (DL)",
    "canonical_path": "50. AI/02 Terminologies/Deep Learning (DL).md",
    "mentions_in_section_body": 3,
    "skip_backfill": false
  }

`skip_backfill: false` here unless the term failed minimum length or was a stopword
escape. The actual Stage 4 skip threshold is evaluated by `terminology-backfill.md`
using `stage2_hits.mentions_in_processed` — see §Skip Criteria below.

Return the hits list to the caller.

**Field-rename note.** The subroutine returns `mentions_in_section_body` (count within
the Transcript / Content section or the processed body section in scope). When Stage 2
promotes these hits into the sidecar's `merged_hits` array, it renames the field to
`mentions_in_processed` to signal scope semantics ("counted in the processed body").
Stage 4 reads `stage2_hits.mentions_in_processed` — not `mentions_in_section_body` —
when evaluating the skip threshold. The rename is intentional and documents the
stage-level scope shift.

## Skip Criteria (evaluated by Stage 4, not by this subroutine)

The skip threshold MUST be evaluated against `stage2_hits.mentions_in_processed` ONLY —
the count from the processed body (Stage 2 output). Do NOT use the `merged_hits` sum,
which conflates raw-transcript and processed-body occurrence counts and would defeat the
threshold's intent.

Skip backfill for a term when ALL of the following are true (logical AND):
  - stage2_hits.mentions_in_processed == 1   (appeared exactly once in processed body)
  - processed_line_count < 100               (processed note is short)

If EITHER condition is false, do NOT skip — proceed to Stage 4 fan-out.

## Sidecar File Spec

Location:  /tmp/ingest-<raw_note_stem>-<yyyymmdd>/
Filename:  <raw_note_stem>_terminology_hits.json
Example:   /tmp/ingest-부잣집 자제들이 가진 진짜 무기-20260417/
             부잣집 자제들이 가진 진짜 무기_terminology_hits.json

The /tmp/ingest-<raw_note_stem>-<yyyymmdd>/ directory is created by Stage 1.

Stage 1 writes the initial sidecar (after the raw note is saved so raw_path is confirmed):
  {
    "raw_path": "/absolute/path/to/raw.md",
    "sidecar_dir": "/tmp/ingest-<raw_note_stem>-<yyyymmdd>/",
    "stage1_hits": [ ... ],
    "stage2_hits": [],
    "merged_hits": [],
    "completed_terms": [],
    "skipped_over_cap": []
  }

Stage 2 reads the sidecar, appends its stage2_hits, recomputes merged_hits, overwrites.

merged_hits = union of stage1_hits + stage2_hits, deduplicated by canonical_path.
For each term in merged_hits, set mentions_in_processed to the stage2_hits value for
that term — NOT the sum of stage1 + stage2 counts. This preserves the skip-threshold
semantics: the threshold tests whether the term is relevant in the *processed* note,
not how many times it appeared in the raw transcript.

Stage 4 deletes the entire /tmp/ingest-<stem>-<yyyymmdd>/ directory after all
subagents complete successfully. If interrupted, the directory remains for resumption.

## Verification Checklist

- [ ] Substitution applied to body text only (lines after closing --- frontmatter fence)
- [ ] Stage 1: restricted to ## Transcript / ## Content section only
- [ ] Per-section substitution (split on ## headings, not per-file)
- [ ] First-occurrence-per-section only
- [ ] Stopwords respected; extensible marker present
- [ ] Korean: exact match only; English: case-insensitive
- [ ] Single-char and sub-word-boundary terms skipped
- [ ] Hits list returned with mentions_in_section_body counts
- [ ] Sidecar written/updated per spec above
- [ ] merged_hits.mentions_in_processed = stage2_hits count only (not sum)
