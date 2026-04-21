---
name: make-skill
description: Author a new agent-skill for this vault, OR update an existing one — wrap Anthropic's `skill-creator` with the vault's own Skill Guideline so every skill lands correctly wired for Obsidian SSOT, `skill-deploy`, and the `{skill-name}.md` metadata stub. Use when the user says "make a skill", "스킬 만들자", "/make-skill", "turn this workflow into a skill", "fix this skill", "update this skill", "edit this skill", or asks to create, scaffold, extract, or update a reusable skill in `50. AI/04 Skills/`.
---

# make-skill

## Overview

Detect create vs update mode, collect a change-reason, draft with a writer subagent that reads the Skill Guideline at runtime, review once with a dedicated reviewer subagent, commit with a Change Log entry appended to the vault stub `{skill-name}.md` (SKILL.md itself never carries the Change Log). Pipeline templates live in `references/pipeline.md`.

## When to Use

- "/make-skill", "make a skill", "스킬 만들자", "skillify this", "update this skill", "fix this skill"
- User wants to capture a repeated workflow or turn a prompt/template into a skill

**NOT for:** prompts under `70. Collections/02 Prompt/` (process SSOT) or templates under `90. Settings/02 Templates/` (format SSOT).

## Dependencies (Check Before Any Work)

Verify both in parallel; abort with a clear error if either fails.

1. `test -f ~/.claude/plugins/marketplaces/anthropic-agent-skills/skills/skill-creator/SKILL.md` — if missing, tell user to install `anthropic-agent-skills` and stop.
2. `test -f "/Users/beomsu/Documents/01. Obsidian/Ataraxia/90. Settings/01 Guideline/Skill Guideline.md"` — if missing, stop and ask user to restore.

## Workflow

### 1. Detect mode and collect change-reason

```bash
SKILL_DIR="/Users/beomsu/Documents/01. Obsidian/Ataraxia/50. AI/04 Skills/<skill-name>"
test -f "$SKILL_DIR/SKILL.md" && mode=update || mode=create
```

- **Update:** read `<change-reason>` from first argument. If absent, invoke `AskUserQuestion` prompt "What is the reason for this update?" with options `["bug fix", "feature addition", "guideline compliance", "other — I'll type it"]`.
- **Same-day duplicate guard:** Change Log lives in the vault stub `{skill-name}.md`. If existing `## Change Log` there has an entry dated `[[<today>]]`, log `WARN: duplicate Change Log entry for today — appending with sequential suffix` and append (never silently overwrite).
- **Create:** writer seeds the initial Change Log entry in the vault stub; no change-reason argument needed.

### 2. Writer subagent invocation

Invoke the writer as specified in `references/pipeline.md § Writer Task`. The writer MUST read `Ataraxia/90. Settings/01 Guideline/Skill Guideline.md` inside its own context before authoring any content. The writer handles the create/update branch and Change Log management per spec.

### 3. Reviewer subagent invocation

Invoke the reviewer as specified in `references/pipeline.md § Reviewer Task`. The reviewer returns a structured verdict. Error-handling contract: if the verdict string cannot be parsed as `approve` or `request_changes`, treat as `approve`, log `WARN: unparseable reviewer verdict — treating as approve`, and commit the current draft without retry. On `request_changes`, re-invoke Writer ONCE with the rationale; commit the second draft unconditionally. Full timeout and post-commit gate contracts live in `references/pipeline.md`.

### 4. Scaffold + vault stub (create mode only)

Directory name is `lowercase-hyphen-separated` and matches `name` frontmatter exactly. Layout: `SKILL.md`, `<skill-name>.md` stub, `references/` (when content > ~100 lines), `scripts/` (optional). Stub frontmatter: `aliases: []`, `date_created: <today>`, `date_modified: <today>`, `tags: []`, `type: skill`, `publish: true`. `publish: true` makes the skill pickable by `skill-deploy`. On update, bump `date_modified`.

### 5. Optional evals + hand off

For objectively verifiable outputs, run Anthropic's eval loop from `skill-creator`; skip for subjective outputs. Point the user at the skill path. If `publish: true`, auto-invoke `Skill("skill-deploy")` — do not merely remind the user.

## Red Flags

- Writing SKILL.md before both dependency checks printed OK
- Directory name mismatched with `name` frontmatter, or Korean body prose (allowed only in example strings)
- Missing `{skill-name}.md` stub, or missing `publish: true` on a deploy-intended skill
- `description` summarizes workflow steps or lacks Korean triggers when user runs Korean workflow
- Change Log section missing or schema-violating after writer pass
- Writer subagent called without an explicit instruction to read Skill Guideline.md in its own context

## Verification

- [ ] Both dependency checks returned OK before any file was written
- [ ] Mode correctly set to `create` or `update` before writer invocation.
- [ ] In update mode: `<change-reason>` collected (argument or AskUserQuestion) before writer called.
- [ ] Writer subagent system prompt included explicit Skill Guideline.md read instruction.
- [ ] Reviewer verdict was `approve` or `request_changes`; if neither, named warning logged and current draft committed.
- [ ] `## Change Log` section present at end of committed `{skill-name}.md` vault stub (never in SKILL.md).
- [ ] First (or only) Change Log entry in the stub matches `^\- \[\[[0-9]{4}-[0-9]{2}-[0-9]{2}\]\]`.
- [ ] Post-commit grep gate ran against the stub and either passed silently or emitted `WARN: Change Log schema violation detected`.
- [ ] Directory created at `50. AI/04 Skills/<skill-name>/` (create mode)
- [ ] `SKILL.md` frontmatter `name` matches the directory name
- [ ] In update mode: original `name` frontmatter preserved exactly
- [ ] `description` covers *what* + *when* and contains the real user phrases
- [ ] SKILL.md body is English-only (Korean allowed only inline inside example strings)
- [ ] `{skill-name}.md` stub exists with `type: skill` and the intended `publish` value
- [ ] On `publish: true`, `Skill("skill-deploy")` was auto-invoked (not just mentioned)
