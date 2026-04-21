# make-skill Writer/Reviewer Pipeline

Authoritative source for the Task() invocation templates referenced from `SKILL.md`. Updates happen here; `SKILL.md` only references these sections by name.

**Change Log location:** the Change Log lives in the vault stub `{SKILL_DIR}/<skill-name>.md`. `SKILL.md` MUST NOT contain a `## Change Log` section.

## § Writer Task

```
Task(
  subagent_type = "oh-my-claudecode:executor",
  model         = "sonnet",
  prompt        = """
    You are a skill author. Your sole responsibility is to produce a compliant SKILL.md
    and a compliant vault stub ({SKILL_DIR}/<skill-name>.md).

    MANDATORY: Before writing anything, read the full Skill Guideline at:
      Ataraxia/90. Settings/01 Guideline/Skill Guideline.md

    Mode: {create | update}
    Target SKILL.md: {SKILL_DIR}/SKILL.md
    Target vault stub: {SKILL_DIR}/<skill-name>.md
    Change reason (update mode only): {change_reason}
    Writer feedback from reviewer (second pass only): {reviewer_rationale}

    Rules:
    - SKILL.md body is English-only. Korean permitted only inside literal example strings.
    - SKILL.md MUST NOT contain a ## Change Log section.
    - On create: write the vault stub with standard frontmatter AND seed ## Change Log
      at the end of the stub with one entry: [[YYYY-MM-DD]] initial creation + 4 sub-bullets.
    - On update: if ## Change Log missing in the stub, create it; if present, append
      a new chronological entry at the bottom of the stub.
    - Existing Change Log entries in the stub MUST NOT be reordered or edited.
    - name frontmatter in SKILL.md must match the directory name exactly.
    - On update: preserve name frontmatter exactly as found; bump date_modified in the stub.

    Output: write the complete SKILL.md to {SKILL_DIR}/SKILL.md and the complete
    vault stub to {SKILL_DIR}/<skill-name>.md.
  """
)
```

## § Reviewer Task

```
Task(
  subagent_type = "oh-my-claudecode:code-reviewer",
  model         = "sonnet",
  prompt        = """
    PERSONA OVERRIDE: You are a document-schema compliance auditor, not a code reviewer.
    Suppress all code-review heuristics (style, complexity, test coverage).
    Your ONLY job is to check three items against the document schema. Do not comment on anything else.

    SKILL.md path: {SKILL_DIR}/SKILL.md
    Vault stub path: {SKILL_DIR}/<skill-name>.md
    Guideline path: Ataraxia/90. Settings/01 Guideline/Skill Guideline.md

    Checklist (evaluate ONLY these):
    1. Guideline compliance: does structure, naming, and section order in SKILL.md match
       Skill Guideline.md? SKILL.md must NOT contain ## Change Log.
    2. English-only body in SKILL.md: is every non-example-string line in English?
    3. Change Log schema in the vault stub: does ## Change Log exist at the end of
       {SKILL_DIR}/<skill-name>.md, with entries matching
       ^\- \[\[[0-9]{4}-[0-9]{2}-[0-9]{2}\]\] .+ and exactly 4 sub-bullets
       (Why/What/Benefit/Reference)?

    Response format (strict — no other content):
    verdict: approve | request_changes
    rationale: <one paragraph, max 150 words, referencing only the checklist items above>
  """
)
```

## § Verdict parsing + error-handling

```
Parse reviewer response for "verdict: approve" or "verdict: request_changes".
- verdict: approve       → commit current draft (SKILL.md + stub). Done.
- verdict: request_changes → re-invoke Writer Task ONCE with reviewer_rationale as feedback.
                             Commit second draft unconditionally (no further review).
- neither string found   → log `WARN: unparseable reviewer verdict — treating as approve`.
                             Commit current draft.
```

## § Timeout contract

```
Each Task() invocation has a timeout of 90 seconds.
- Writer Task timeout   → abort, surface error, do NOT commit a partial file.
                          Log `WARN: Task timeout after 90s — writer aborted`.
- Reviewer Task timeout → treat as approve; commit writer's draft.
                          Log `WARN: Task timeout after 90s — reviewer skipped`.
```

## § Post-commit verification gate

```bash
# Change Log lives in the vault stub, NOT in SKILL.md.
STUB="$SKILL_DIR/$(basename "$SKILL_DIR").md"
grep -E '^\- \[\[[0-9]{4}-[0-9]{2}-[0-9]{2}\]\]' "$STUB" \
  || echo "WARN: Change Log schema violation detected"

# SKILL.md must NOT contain a Change Log section.
grep -q '^## Change Log' "$SKILL_DIR/SKILL.md" \
  && echo "WARN: Change Log schema violation detected — found in SKILL.md (should live in the vault stub)"
```
Run after every commit. On any warning, surface to user and continue (do not abort).
