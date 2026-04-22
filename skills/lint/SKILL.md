---
name: lint
description: >-
  Detect and safely fix guideline violations in an Obsidian vault across
  frontmatter, tags, folder naming, YAML structure, MOC assignments, and
  AGENTS.md files. Reads the guideline folder fresh at startup; runs bundled
  deterministic scripts in three phases (inspect / execute / review); applies
  mutations through the Obsidian eval engine to preserve wikilinks and
  backlinks. Use when the user requests a vault audit, guideline compliance
  scan, frontmatter cleanup, tag cleanup, or vault health check.
argument-hint: "[--guideline-dir <path>] [--phase inspect|execute|review] [--scope <folder>] [--dry-run]"
---

# lint

## Overview

`lint` is the vault's three-phase guideline-compliance engine. It reads guideline files under `90. Settings/01 Guideline/` (plus depth-1 and depth-2 `AGENTS.md` files) on every invocation, runs bundled inspection scripts to surface all mechanically-checkable violations, then applies safe auto-fixes through the Obsidian eval engine to preserve wikilinks and backlinks. It is not a knowledge-enrichment or wiki-generation tool — that concern belongs to the future `wiki` skill.

## Vault Access

Use the `obsidian-cli` skill for all note creation, edit, search, and property mutation inside the Ataraxia vault. Do not shell out to raw `cat`/`sed` on vault paths. See the `obsidian-cli` SKILL.md for the command surface and required preconditions (Obsidian must be running).

## When to Use

**Use when:**

- User requests a vault audit, health check, or guideline compliance scan.
- Batch frontmatter normalization needed before or after a content migration.
- A scoped folder needs inspection before automated fixes are applied.
- Pre-identified violations from the deep-interview spec need surfacing and confirmation.
- A new guideline was published and the vault needs auditing against it.

**NOT for:**

- Free-form content writing or note creation.
- Wiki / knowledge-graph generation (use the future `wiki` skill).
- Reference intake from articles or videos (use the future `inject` skill).
- Terminology creation or merging (use the `terminology` skill).
- Running mutations without first completing a dry-run + user-confirmation cycle in interactive mode.

### Korean Input Examples

The following are literal Korean input phrases a user may type. They trigger the `lint` skill.

```
볼트 점검
가이드라인 검사
프론트매터 정리
태그 정리
```

## Core Process

### Structured Diff Format (canonical)

All structured diffs produced by this skill use this format:

```
[DRY-RUN] Would fix: <relative/path/to/file.md>
          <field>: '<old_value>' → '<new_value>'
          <field2>: '<old_value2>' → '<new_value2>'
```

Shell scripts emit this format. Eval-engine mutations produce the same format from the `vault.read → lintText` comparison before any `vault.modify()` call. For multi-property or body changes, a property-change table is used.

---

### Phase 1 — INSPECT (read-only)

**Step 1.1 — Load guidelines and env vars.**
Accept `--guideline-dir` argument (default: `Ataraxia/90. Settings/01 Guideline/`). Read all guideline files fresh. Read depth-1 and depth-2 `AGENTS.md` files. Extract and export env vars:

- `REQUIRED_FIELDS_JSON`
- `DEPRECATED_KEYS_JSON`
- `ALLOWED_STATUS_JSON`
- `STATUS_REQUIRED_TYPES_JSON`
- `ALLOWED_TYPES_JSON`
- `TYPE_TAG_MAP_JSON`
- `FOLDER_TYPE_RULES_JSON`

Source shapes from `lint/assets/env-vars-template.json`.

AGENTS.md violations (e.g., root `AGENTS.md:8` gh-scope error, `70. Collections/AGENTS.md:14` stale path) are detected here by reading and diffing the AGENTS.md files directly — not by a bundled script. They are reported in the Phase 1 dashboard under "Human-review / judgment required" and are not auto-fixed.

**Step 1.2 — Eval-engine preflight.**
Run `lint/scripts/verify-eval-engine.sh`. If any of the 4 checks fail, refuse to proceed — emit the named failing check and stop.

**Step 1.3 — Run inspection scripts in parallel.**
Run all 6 inspection scripts in parallel (parallel Bash calls in one message) with the vault path, optional `--scope`, and exported env vars. Invoke by absolute path under `lint/scripts/`.

Scripts: `inspect-frontmatter.sh`, `inspect-tags.sh`, `inspect-types.sh`, `inspect-moc.sh`, `inspect-yaml.sh`, `inspect-overview.sh`.

**Step 1.4 — Present Vault Health Dashboard.**
Violation counts by category, auto-fixable vs. judgment-required, by-folder breakdown, AGENTS.md violations (human-review items), pre-identified violations from the spec.

---

### Phase 2 — EXECUTE (write, requires approval)

**Step 2.1 — Confirm Phase 1 dashboard.**
Without `--auto`, proceed only after user confirms the Phase 1 dashboard.

**Step 2.2 — Shell-script fix path.**
Applies to: YAML delimiters, status values, date format, legacy tags, tag parent-child, type case.

Run the relevant `fix-*.sh` script with `--dry-run`. Scripts emit the structured diff format. Present the full diff to the user. On confirmation, re-run without `--dry-run`.

**Step 2.3 — Eval-engine fix path.**
Applies to: frontmatter edits requiring linter-plugin semantics (key sort, blank-line enforcement, timestamp handling).

`runLinterFile()` is a `Promise<void>` that calls `vault.modify()` directly with no return value and no dry-run mode. It cannot produce a diff. **`runLinterFile()` is never called.**

The correct pattern is `vault.read → lintText → diff → confirm → vault.modify`:

```javascript
// Step A: compute diff (read-then-lintText)
(async () => {
  const tfile = app.vault.getAbstractFileByPath("relative/path/to/file.md");
  const before = await app.vault.read(tfile);
  const linterPlugin = app.plugins.plugins['obsidian-linter'];
  const after = linterPlugin.rulesRunner.lintText(
    before, tfile, app, false  // isManualRun=false
  );
  return JSON.stringify({ before, after });
})()
```

Present the diff (property-change table or unified diff) to the user. Apply only on confirmation:

```javascript
// Step B: apply on confirmation only
(async () => {
  const tfile = app.vault.getAbstractFileByPath("relative/path/to/file.md");
  await app.vault.modify(tfile, /* after-text from Step A */);
})()
```

Step A and Step B replace `runLinterFile()`: the executor controls the write and the user confirms the diff before any mutation.

**Step 2.4 — Renames.**
For renames that must preserve backlinks, use `app.fileManager.renameFile(tfile, newPath)` via eval. User confirms the rename before the eval call is made. No diff is needed for renames — the old and new path are explicit.

**Step 2.5 — Judgment fixes.**
Group missing `type`, missing `moc`, and AGENTS.md corrections; propose them to the user. Do not auto-apply judgment fixes without `--auto`.

---

### Phase 3 — REVIEW (read-only)

Re-run all 6 inspection scripts on the same scope. Compare before/after violation counts per category using the structured diff format. Report: fixed, remaining, manual-review items. If regressions found, loop back to Phase 2 (max 3 retries).

---

### Guideline-Path-Injection Pattern

> Never hard-code any rule. `--guideline-dir` is the sole source of truth. If a guideline changes, re-running `lint` picks it up — no skill update required.

---

### Scripts-as-Assets Invocation Contract

> Always invoke scripts by absolute path under `lint/scripts/`. Never regenerate or modify scripts during a run. File a separate fix task if a script is wrong.

## Plugin Dependencies

| Plugin ID | Version | Required / Optional | Purpose | Fallback |
|---|---|---|---|---|
| obsidian-linter | >= 1.31.0 | **Required** | `lintText()` for pre-diff; `rulesRunner` for Phase 2 eval-engine path | **BLOCKED — refuse to proceed with Phase 2 execute.** Phase 1 inspect and Phase 3 review are unaffected. |
| obsidian-automover | any | Optional | Automatic file relocation on type/folder changes | Manual rename via `app.fileManager.renameFile()` |
| obsidian-dataview | any | Optional | Overview phase aggregate queries | `bash find` + Python counts |

If `obsidian-linter` is not enabled, Check 3 fails and the skill refuses Phase 2 execute. Phase 1 inspect scripts are pure Python/shell and are unaffected.

Clear error: `FAIL [Check 3]: obsidian-linter plugin is not enabled. Enable it in Obsidian Settings > Community Plugins > obsidian-linter before running --phase execute.`

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I can skip --dry-run and apply fixes directly; I know what I'm changing." | Without a dry-run diff, you cannot prove the fix is correct or scope-limited. Every mutation requires a preceding diff — non-negotiable. |
| "I can skip verify-eval-engine.sh; Obsidian is obviously running." | The preflight checks verify Obsidian is running, the Linter plugin is enabled, and obsidian-cli resolves. Skipping it causes a silent mid-run failure on the first API call. |
| "The guideline rules are stable; I can hard-code them in the script." | Guidelines change. Hard-coded rules create a second SSOT that drifts silently. Always read rules from the guideline folder at runtime via exported env vars. |
| "I can call runLinterFile() directly — it will handle everything." | `runLinterFile()` is a `Promise<void>` that writes to disk immediately with no diff, no dry-run mode, and no return value. Calling it without `vault.read → lintText → diff → confirm` can silently overwrite 300+ files. |
| "I'll use app.vault.modify() for renames — it's faster." | `app.vault.modify()` does not update wikilinks or backlinks. All renames must go through `app.fileManager.renameFile()`. `vault.modify()` is only acceptable for confirmed in-place content edits from the Step B eval pattern. |

## Red Flags

- **Broken wikilinks after a run** — rename was done via raw fs or `app.vault.modify()` instead of `app.fileManager.renameFile()`.
- **Korean prose in SKILL.md instruction text** — Korean is only permitted inside `### Korean Input Examples`; nowhere else in the body, headings, or rationale.
- **Guideline rules inlined into scripts or SKILL.md** — hard-coded rules duplicate guideline files and drift silently when guidelines change.
- **Phase 2 executed without a Phase 1 dashboard** — fixes applied without a baseline violation count leave no before/after proof and no way to audit scope.
- **`runLinterFile()` called without a preceding pre-diff** — direct mutation without a user-confirmed diff is a data-loss risk on a 2000+ file vault with no git.
- **Scripts regenerated by the model during a lint run** — bundled scripts are authoritative; model-generated ad hoc scripts are untested and may contradict bundled logic.
- **`obsidian-vault-doctor/` deleted before Check 7 passes** — premature deletion removes the rollback path if a migrated script has a regression.

## Verification

- [ ] `lint/SKILL.md` exists; `name: lint` in frontmatter; description ≤ 1024 characters (verified with `wc -c`).
- [ ] SKILL.md body is fully English; `grep -c "[가-힣]" lint/SKILL.md` returns 0 outside the `### Korean Input Examples` subsection.
- [ ] `lint/scripts/` contains exactly 15 files: 5 `inspect-*.sh`, 6 `fix-*.sh`, `verify-eval-engine.sh`, `frontmatter_parser.py`, `test_frontmatter_parser.py`.
- [ ] Consolidated vault-name grep across all 5 CLI-using fix scripts returns nothing.
- [ ] `bash lint/scripts/fix-yaml-delimiters.sh <vault> --dry-run` exits 0 without Obsidian running (pgrep guard removed).
- [ ] `bash lint/scripts/verify-eval-engine.sh` exits 0 on a healthy vault; exits 1 with a named failing check for each of the four simulated failure modes.
- [ ] `lint --phase inspect --dry-run` dashboard surfaces all 8 pre-identified violations (items 4, 7, 8 under "human-review / policy-decision required").
- [ ] `lint --phase execute --dry-run` on a sample violating file emits a structured diff without mutating the file (md5sum before and after are identical).
- [ ] `obsidian-vault-doctor/` directory is absent after the 7-point gate passes.
