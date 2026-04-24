---
name: obsidian-vault-doctor
description: >-
  Scan an Obsidian vault against its guideline documents, detect violations,
  auto-fix safe issues, and save reusable diagnostic scripts. Trigger on:
  "vault health", "vault check", "vault doctor", "볼트 점검", "볼트 닥터",
  "가이드라인 검사", "프론트매터 정리", "태그 정리", "vault audit", "health check",
  "vault lint". Use this skill whenever the user wants to audit vault
  consistency, fix frontmatter issues, or run periodic maintenance.
argument-hint: "<guideline-path> [--phase inspect|execute|review] [--scope <folder>] [--dry-run]"
---

# Vault Health Check

Scan the vault against its own guideline documents.
Read guidelines fresh every run — no caching, no manifest, no hash comparison.

## Prerequisites

Verify Bash permission before any work. If denied, stop and ask the user to enable it.

## Arguments

| Arg | Default | Description |
|-----|---------|-------------|
| `guideline-path` | `90. Settings/91. Guideline/` | Path to guideline directory |
| `--phase` | all three | Run a specific phase only |
| `--scope` | entire vault | Limit scan to a folder |
| `--dry-run` | false | Phase 2: show fixes without applying |
| `--auto` | false | Skip all confirmations. Safe fixes applied immediately, judgment fixes reported only |
| `--quiet` | false | Suppress output when zero violations and zero fixes. For `/loop` usage |

## Guideline Registry

Read only `00`–`04`. Ignore `05`–`11`.

| Guideline | Domain | Extracted Env Vars |
|-----------|--------|--------------------|
| `00. Core Guideline` | Frontmatter structure | `REQUIRED_FIELDS_JSON`, `DEPRECATED_KEYS_JSON`, `ALLOWED_STATUS_JSON`, `STATUS_REQUIRED_TYPES_JSON` |
| `01. Frontmatter Guideline` | Type & content | `ALLOWED_TYPES_JSON`, `TYPE_TAG_MAP_JSON`, `FOLDER_TYPE_RULES_JSON` |
| `02. Folder Guideline` | Folder placement | (구조적 규칙 — 스크립트 내장) |
| `03. Tag Guideline` | Tag rules | (구조적 규칙 — 스크립트 내장) |
| `04. MOC Guideline` | MOC assignment | (구조적 규칙 — 스크립트 내장) |

## Scripts

Pre-built scripts live in this skill's `scripts/` directory.
Run them directly. Do not regenerate with LLM.

| Script | Purpose |
|--------|---------|
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

## Phase 1: INSPECT (read-only)

Do not modify files in this phase.

### Step 1.1 — Read Guidelines & Extract Rules

Read all 5 guideline files (00–04) from the guideline path.
For each env var below, read the specified guideline section and construct the JSON value dynamically.
Do NOT use cached or memorized values — always extract fresh from the current guideline text.

Refer to `<skill-dir>/assets/env-vars-template.json` for the exact JSON shape and source mapping of each variable.

**Extraction Protocol:**

| Env Var | Source File | Section | How to Extract |
|---------|-----------|---------|----------------|
| `REQUIRED_FIELDS_JSON` | `00. Core Guideline` | §1.1 Core Required Fields | 테이블 1열의 backtick 내 필드명을 JSON 배열로 수집 |
| `DEPRECATED_KEYS_JSON` | `00. Core Guideline` | §1.3 Deprecated Keys | 테이블 1열 (Deprecated 열)의 backtick 내 키명을 JSON 배열로 수집 |
| `ALLOWED_STATUS_JSON` | `00. Core Guideline` | §1.4 Status Values | 테이블 1열 (Value 열)의 backtick 내 값을 JSON 배열로 수집 |
| `STATUS_REQUIRED_TYPES_JSON` | `00. Core Guideline` | §1.4 Status Values | "**필수 유형**" 뒤 backtick으로 감싼 type 목록을 JSON 배열로 수집 |
| `ALLOWED_TYPES_JSON` | `01. Frontmatter Guideline` | §1 Type Map 테이블 | 1열 (Type 열)의 backtick 내 type 값을 JSON 배열로 수집 |
| `TYPE_TAG_MAP_JSON` | `01. Frontmatter Guideline` | §1 Type Map 테이블 | References 카테고리의 type을 `{"type": "reference/type"}` 형태의 JSON 객체로 구성 |
| `FOLDER_TYPE_RULES_JSON` | `01. Frontmatter Guideline` | Caveats §1 (project vs log) | 3-rule decision tree를 아래 형식의 JSON 객체로 구성 |

**Export format** — 각 변수를 아래 형식으로 export:

```bash
export REQUIRED_FIELDS_JSON='[<00.Core §1.1에서 추출>]'
export DEPRECATED_KEYS_JSON='[<00.Core §1.3에서 추출>]'
export ALLOWED_STATUS_JSON='[<00.Core §1.4에서 추출>]'
export STATUS_REQUIRED_TYPES_JSON='[<00.Core §1.4 필수 유형에서 추출>]'
export ALLOWED_TYPES_JSON='[<01.Frontmatter Type Map에서 추출>]'
export TYPE_TAG_MAP_JSON='{<01.Frontmatter References 카테고리에서 도출>}'
export FOLDER_TYPE_RULES_JSON='{"folders":[<추출>],"index_type":"<추출>","date_prefix_type":"<추출>","default_type":"<추출>","suffix_overrides":{<추출>}}'
```

`FOLDER_TYPE_RULES_JSON` 필드 설명:
- `folders`: 3-rule type logic 적용 대상 최상위 폴더
- `index_type`: `<폴더명>.md` (filename matches subfolder name) 의 type
- `date_prefix_type`: `YYYY-MM-DD <이름>.md` 의 type
- `default_type`: 그 외 모든 노트의 type
- `suffix_overrides`: filename suffix → type override (checked before other rules)

**Verification** — export 후, 추출된 값을 요약 출력하여 가이드라인과 대조:

```
Extracted rules from guidelines:
  REQUIRED_FIELDS:        N fields
  DEPRECATED_KEYS:        N keys
  ALLOWED_STATUS:         N values
  STATUS_REQUIRED_TYPES:  N types
  ALLOWED_TYPES:          N types
  TYPE_TAG_MAP:           N mappings
  FOLDER_TYPE_RULES:      N folders, index=X, date_prefix=Y, default=Z
```

추출된 값이 비어있거나 예상보다 현저히 적으면 해당 가이드라인 섹션을 다시 읽고 재추출한다.

### Step 1.2 — Run Diagnostic Scripts

Run each inspect script via Bash. Each script walks the vault once in Python
and outputs structured results.

```bash
# All 7 env vars from Step 1.1 must be exported before running these scripts.
# Scripts will fail with a clear error if any required env var is missing.
bash "<skill-dir>/scripts/inspect-frontmatter.sh" "<vault-path>"
bash "<skill-dir>/scripts/inspect-tags.sh" "<vault-path>"
bash "<skill-dir>/scripts/inspect-types.sh" "<vault-path>"
bash "<skill-dir>/scripts/inspect-moc.sh" "<vault-path>"
bash "<skill-dir>/scripts/inspect-yaml.sh" "<vault-path>"
bash "<skill-dir>/scripts/inspect-overview.sh" "<vault-path>"
```

Run all 6 in parallel (separate Bash calls in one message).

If a script checks rules that guidelines no longer require,
update the script to match current guidelines before running.

### Step 1.3 — Present Dashboard

Compile script outputs into a dashboard:

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
|---|------|-------|-------------|

### By Folder
| Folder | Violations | Most common |
|--------|-----------|-------------|
```

If `--auto`: skip to Phase 2 automatically when violations exist.
If `--quiet` AND zero violations: stop here with no output.
Otherwise: ask the user "Phase 2 (fix)?"

## Phase 2: EXECUTE (write, requires approval)

Without `--auto`: proceed only after user confirms Phase 1 dashboard.
With `--auto`: proceed immediately. Safe fixes apply without confirmation.

### Step 2.1 — Auto-Fix Safe Violations

Write and run a single Python script per fix category.

Safe fix patterns (apply without asking):
- YAML `-----` to `---` at frontmatter boundaries
- Malformed opener `---aliases: []` to `---\naliases: []`
- Quoted status (`"done"` to `done`)
- Date timestamps (`2026-01-01T00:00` to `2026-01-01`)
- Deprecated keys (`created_at` to `date_created`)
- Missing required fields (`aliases: []`, `tags: []`, `date_created: <today>`)

Report count fixed per category.

### Step 2.2 — Propose Judgment Fixes

Group violations needing user judgment by type and propose:
- `type:` missing or wrong — suggest based on `FOLDER_TYPE_RULES_JSON` (Step 1.1에서 추출한 folder-to-type 매핑 규칙 참조)
- `moc:` missing in PN — suggest based on tags + content keywords
- Invalid type values — suggest replacement

Without `--auto`: use subagents for large-scale judgment fixes (type assignment, MOC mapping).
With `--auto`: do not apply. Report remaining judgment fixes in output only.

### Step 2.3 — Save Fix Scripts

Save executed fix commands to the skill's `scripts/` directory for reuse.

## Phase 3: REVIEW (read-only)

### Step 3.1 — Re-Run Diagnostics

Run the same inspect scripts from Phase 1. Compare before/after.

### Step 3.2 — Verdict

- **PASS**: no regressions AND resolved count > 0
- **FAIL**: regressions found — loop to Phase 2 (max 3 retries)

### Step 3.3 — Final Report

With `--auto --quiet`:
- Zero violations AND zero fixes → no output, stop silently.
- Safe fixes applied, zero remaining → one-line summary: `"✅ N건 자동 수정 (category1 X, category2 Y)"`
- Judgment fixes remaining → full report below.

Otherwise, full report:

```
## Health Check Complete

| Metric          | Before | After | Delta |
|-----------------|--------|-------|-------|
| Total violations| X      | Y     | -Z    |
| Auto-fixed      |        | N     |       |
| User-approved   |        | M     |       |
| Remaining       |        | R     |       |
```

## Scope Control

- Always skip `.obsidian/`, `.trash/`, `.git/`, `.omc/`, `.claude/`, `_archive/`, `92. Templates/`.
- First run: focus on auto-fixable violations first.
- Subsequent runs: progressively tackle `suggest` items.
- If `--scope` is given, scan that folder only.

## Obsidian CLI Reference

```bash
obsidian properties counts format=json
obsidian tags counts format=json
obsidian unresolved verbose format=json
obsidian orphans total
obsidian files total
```

## Caveats

### Sequential Obsidian verification after sample repair

Before any vault-wide execute pass, verify one repaired real note sequentially:

1. `sed -n '1,12p' <path>` — confirm the file now starts with standalone `---`
2. `obsidian properties path="<vault-relative-path>" vault="<vault-name>"` — confirm Obsidian sees frontmatter
3. `obsidian property:read name="type" ...` then `name="aliases" ...` — confirm key properties resolve
4. `obsidian eval` against `app.metadataCache.getFileCache(...)` — confirm `frontmatter` is non-null and contains the expected keys

Do this on one bad note and one known-good control note. Do not trust grep alone for runtime verification.

### Anti-pattern: Grep-based piecemeal counting

Calling Grep/Glob dozens of times to count individual fields produces outputs
of hundreds of KB with no way to extract totals efficiently. Use a single-pass
Python script that walks the vault once and collects all metrics in one run.

### Anti-pattern: Delegating Phase 1 to subagents

Spawning explore/executor agents for diagnostic scanning can fail entirely
if Bash permissions are restricted. Run Phase 1 directly in the main context.
Reserve subagents for Phase 2 judgment fixes only (type/moc assignment).

### Anti-pattern: Cache/manifest system

The 5 guideline files total ~25K tokens. The complexity of SHA-256 hash
comparison, manifest management, and partial regeneration logic exceeds the
cost of reading them every time. Read fresh on every run.

### False positive: `^  - [A-Z]` for uppercase tag detection

This pattern matches all YAML list items (`moc:`, `related:`, etc.),
not just tags. Apply uppercase checks only to items within the `tags:` section
of frontmatter.

### False positive: Unquoted wikilink over-detection

Three cases that look like violations but are not:
- `banner: "![[...]]"` — already quoted; `"![[` differs from `"[["`
- `description:` with inline `[[...]]` — text-embedded wikilink, not a standalone value
- `up: '[[...]]'` (single quotes) — valid YAML quoting

Do not flag these as violations.

### False positive: `status:` treated as universally required

`status` is type-conditional. Required only for types listed in
`STATUS_REQUIRED_TYPES_JSON`. Do not flag missing `status` on Daily Notes,
Terminology, or other types.

### Deprecated property removal — check .base files

When a property is deprecated (e.g., `priority`), `.base` files that sort or filter by that property will silently break. After removing a deprecated property from notes, scan `.base` files before applying the fix at scale:

```bash
grep -r 'priority' "<vault-path>" --include='*.base'
```

Update or remove any `sort`, `filter`, or `order` references to the deprecated property in the affected `.base` files.
