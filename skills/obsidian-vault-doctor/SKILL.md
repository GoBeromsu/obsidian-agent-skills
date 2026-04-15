---
name: obsidian-vault-doctor
description: >-
  Scan an Obsidian vault against its guideline documents, detect violations,
  auto-fix safe issues, and save reusable diagnostic scripts. Trigger on:
  "vault health", "vault check", "vault doctor", "볼트 점검", "볼트 닥터",
  "가이드라인 검사", "프론트매터 정리", "태그 정리", "vault audit", "health check",
  "vault lint". Use this skill whenever the user wants to audit vault
  consistency, fix frontmatter issues, or run periodic maintenance.
argument-hint: "90. Settings/01 Guideline/ [--phase inspect|execute|review] [--scope <folder>] [--dry-run]"
---

# obsidian-vault-doctor

## Overview

Three-phase vault-health audit: INSPECT (read-only diagnostics) → EXECUTE (safe auto-fixes + judgment proposals) → REVIEW (re-run diagnostics, compare before/after). Guidelines live at `90. Settings/01 Guideline/` (files `00`–`07`). Read guidelines fresh every run — no caching. Bundled scripts at `55. Tools/03 Skills/obsidian-vault-doctor/scripts/`. Run them directly; do not regenerate with the model.

## When to Use

- Use when the user asks for a vault audit, vault doctor pass, frontmatter cleanup, or guideline-based maintenance
- Use when a scoped folder needs inspection before automated fixes
- Use when bundled doctor scripts should be used instead of one-off helpers
- Do not use for free-form content writing or unrelated plugin development

## Process

### Phase 1: INSPECT (read-only)

#### Step 1.1 — Read Guidelines and Extract Rules

Read guideline files `00`–`04` from `90. Settings/01 Guideline/`. Ignore `05`–`07`. Extract these env vars dynamically — never use cached values:

| Env Var | Source | Section |
|---|---|---|
| `REQUIRED_FIELDS_JSON` | `00. Core Guideline` | §1.1 Core Required Fields |
| `DEPRECATED_KEYS_JSON` | `00. Core Guideline` | §1.3 Deprecated Keys |
| `ALLOWED_STATUS_JSON` | `00. Core Guideline` | §1.4 Status Values |
| `STATUS_REQUIRED_TYPES_JSON` | `00. Core Guideline` | §1.4 Status Values (필수 유형) |
| `ALLOWED_TYPES_JSON` | `01. Frontmatter Guideline` | §1 Type Map |
| `TYPE_TAG_MAP_JSON` | `01. Frontmatter Guideline` | §1 Type Map (References) |
| `FOLDER_TYPE_RULES_JSON` | `01. Frontmatter Guideline` | Caveats §1 |

Export format:
```bash
export REQUIRED_FIELDS_JSON='[...]'
export DEPRECATED_KEYS_JSON='[...]'
export ALLOWED_STATUS_JSON='[...]'
export STATUS_REQUIRED_TYPES_JSON='[...]'
export ALLOWED_TYPES_JSON='[...]'
export TYPE_TAG_MAP_JSON='{...}'
export FOLDER_TYPE_RULES_JSON='{"folders":[...],"index_type":"...","date_prefix_type":"...","default_type":"...","suffix_overrides":{...}}'
```

Refer to `55. Tools/03 Skills/obsidian-vault-doctor/assets/env-vars-template.json` for the exact JSON shape and source mapping. After exporting, print a summary to verify counts against the guidelines.

#### Step 1.2 — Run Diagnostic Scripts

All 7 env vars from Step 1.1 must be exported before running scripts.

```bash
bash "55. Tools/03 Skills/obsidian-vault-doctor/scripts/inspect-frontmatter.sh" "/Users/beomsu/Documents/01. Obsidian/Ataraxia"
bash "55. Tools/03 Skills/obsidian-vault-doctor/scripts/inspect-tags.sh" "/Users/beomsu/Documents/01. Obsidian/Ataraxia"
bash "55. Tools/03 Skills/obsidian-vault-doctor/scripts/inspect-types.sh" "/Users/beomsu/Documents/01. Obsidian/Ataraxia"
bash "55. Tools/03 Skills/obsidian-vault-doctor/scripts/inspect-moc.sh" "/Users/beomsu/Documents/01. Obsidian/Ataraxia"
bash "55. Tools/03 Skills/obsidian-vault-doctor/scripts/inspect-yaml.sh" "/Users/beomsu/Documents/01. Obsidian/Ataraxia"
bash "55. Tools/03 Skills/obsidian-vault-doctor/scripts/inspect-overview.sh" "/Users/beomsu/Documents/01. Obsidian/Ataraxia"
```

Run all 6 in parallel (separate Bash calls in one message). `frontmatter_parser.py` is the shared Python helper used by multiple scripts.

Full script inventory in `scripts/`:

| Script | Purpose |
|---|---|
| `frontmatter_parser.py` | Shared frontmatter classification and repair helper |
| `inspect-frontmatter.sh` | Required fields, deprecated keys, invalid status/type |
| `inspect-tags.sh` | Tag case, hierarchy, format |
| `inspect-types.sh` | Type coverage, allowed values |
| `inspect-moc.sh` | MOC assignment, Tier 0, PN coverage |
| `inspect-yaml.sh` | Structural YAML errors, date format |
| `inspect-overview.sh` | Total counts, folder distribution |
| `fix-yaml-delimiters.sh` | `----+` to `---` and `---<key>:` opener repair |
| `fix-status-values.sh` | Quoted/invalid status normalization |
| `fix-date-format.sh` | Timestamp to date-only |
| `fix-legacy-tags.sh` | Zettel/P to permanent, Korean to English |
| `fix-tag-parent-child.sh` | Remove parent when child exists |
| `fix-type-case.sh` | Type value normalization |
| `test_frontmatter_parser.py` | Fixture-style checks for parser and fixer logic |

#### Step 1.3 — Present Dashboard

```
## Vault Health Dashboard

| Metric              | Value    | Coverage |
|---------------------|----------|----------|
| Total notes         | X        |          |
| type assigned       | X / Y    | Z%       |
| tags present        | X / Y    | Z%       |
| moc assigned (PN)   | X / Y    | Z%       |
| YAML errors         | X        |          |
| Deprecated keys     | X        |          |

### Top Violations
| # | Rule | Count | Auto-fixable |

### By Folder
| Folder | Violations | Most common |
```

If `--auto`: skip to Phase 2 automatically when violations exist.
If `--quiet` AND zero violations: stop silently.
Otherwise: ask the user "Phase 2 (fix)?"

### Phase 2: EXECUTE (write, requires approval)

Without `--auto`: proceed only after user confirms Phase 1 dashboard.

#### Step 2.1 — Auto-Fix Safe Violations

Use bundled `fix-*.sh` scripts. Safe fix patterns (apply without asking):
- YAML `-----` → `---` at frontmatter boundaries
- Malformed opener `---aliases: []` → `---\naliases: []`
- Quoted status (`"done"` → `done`)
- Date timestamps (`2026-01-01T00:00` → `2026-01-01`)
- Deprecated keys (`created_at` → `date_created`)
- Missing required fields (`aliases: []`, `tags: []`, `date_created: <today>`)

Report count fixed per category.

#### Step 2.2 — Propose Judgment Fixes

Group violations needing user judgment:
- `type:` missing or wrong — suggest based on `FOLDER_TYPE_RULES_JSON`
- `moc:` missing in PN — suggest based on tags + content keywords
- Invalid type values — suggest replacement

Without `--auto`: use subagents for large-scale judgment fixes. With `--auto`: report remaining judgment fixes only, do not apply.

#### Step 2.3 — Save Fix Scripts

Save executed fix commands to `55. Tools/03 Skills/obsidian-vault-doctor/scripts/` for reuse.

### Phase 3: REVIEW (read-only)

Re-run the same 6 inspect scripts. Compare before/after.

- **PASS**: no regressions AND resolved count > 0
- **FAIL**: regressions found — loop to Phase 2 (max 3 retries)

Final report:
```
## Health Check Complete

| Metric          | Before | After | Delta |
|-----------------|--------|-------|-------|
| Total violations| X      | Y     | -Z    |
| Auto-fixed      |        | N     |       |
| User-approved   |        | M     |       |
| Remaining       |        | R     |       |
```

With `--auto --quiet` and zero remaining: one-line summary only.

## Scope Control

Always skip: `.obsidian/`, `.trash/`, `.git/`, `.omc/`, `.claude/`, `_archive/`, `92. Templates/`.

Use `--scope <folder>` to limit scan to a specific folder.

## Obsidian CLI Reference (for vault stats)

```bash
obsidian vault="Ataraxia" properties counts format=json
obsidian vault="Ataraxia" tags counts format=json
obsidian vault="Ataraxia" unresolved verbose format=json
obsidian vault="Ataraxia" orphans total
obsidian vault="Ataraxia" files total
```

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I can skip the inspect pass and just run fixes." | Without a baseline, you cannot prove what changed or whether the fix was appropriate. |
| "I should regenerate a new script with the model." | This skill ships 14 deterministic scripts; use them first. |
| "A clean script exit means the vault is healthy." | Post-fix reinspection is required to prove the result. |
| "I can grep-count fields instead of running the scripts." | Grep-based piecemeal counting produces hundreds of KB of output with no extractable totals. Use single-pass Python. |

## Red Flags

- Fixes applied before an inspection summary is produced
- Bundled scripts ignored in favor of ad hoc one-off scripts
- Fixes reported without a post-fix verification pass
- Guidelines cached from a previous run instead of read fresh
- Phase 1 delegated to subagents (Bash permission failures can silently drop diagnostic data)

## Verification

After completing the workflow, confirm:

- [ ] Guideline files `00`–`04` read fresh before inspection
- [ ] All 6 inspect scripts ran and produced output
- [ ] Auto-fixes limited to deterministic safe patterns (bundled `fix-*.sh` scripts)
- [ ] Post-fix inspect scripts reran and showed delta
- [ ] Judgment fixes proposed but not auto-applied (without `--auto`)
- [ ] Fix scripts saved to `55. Tools/03 Skills/obsidian-vault-doctor/scripts/` for reuse
- [ ] Final report separates fixed, remaining, and manual-review items
