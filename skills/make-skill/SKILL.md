---
name: make-skill
description: Author a new agent-skill for this vault — wrap Anthropic's `skill-creator` with the vault's own Skill Guideline so every new skill lands correctly wired for Obsidian SSOT, `skill-deploy`, and the `{skill-name}.md` metadata stub. Use when the user says "make a skill", "스킬 만들자", "/make-skill", "turn this workflow into a skill", or asks to create, scaffold, or extract a reusable skill from the current session into `50. AI/04 Skills/`.
---

# make-skill

## Overview

Creating a publishable skill from scratch is a repeated workflow: (1) run Anthropic's `skill-creator` to draft the SKILL.md, (2) apply the vault's Skill Guideline (English-only body, standard sections, `{skill-name}.md` stub with `publish: true`), (3) place everything under `50. AI/04 Skills/<skill-name>/` so `skill-deploy` can pick it up. This skill wraps that path and fails fast if either dependency is missing.

## When to Use

- User asks to create, scaffold, or extract a skill from the current conversation
- User says "/make-skill", "make a skill", "make-skill", "스킬 만들자", "skillify this"
- User has a repeated workflow they just ran and wants it captured
- User wants to turn an existing prompt/template into a skill

**NOT for:**
- Editing an existing skill that already has SKILL.md — edit directly, or use Anthropic's `skill-creator` for its eval loop
- Creating prompts under `70. Collections/02 Prompt/` — those are the process SSOT, not the agent-facing wrapper
- Creating templates under `90. Settings/02 Templates/` — those are the format SSOT

## Dependencies (Check Before Any Work)

Before drafting any content, verify both dependencies exist and abort with a clear error if either is missing. These checks are cheap and catch the "it works on my machine" case before the skill is half-written.

1. **Anthropic `skill-creator` installed**
   ```bash
   test -f ~/.claude/plugins/marketplaces/anthropic-agent-skills/skills/skill-creator/SKILL.md \
     && echo OK || echo "MISSING: install anthropic-agent-skills plugin"
   ```
   If missing, instruct the user: `claude plugins install anthropic-agent-skills` (or whichever marketplace install command matches their setup) and stop.

2. **Skill Guideline SSOT exists**
   ```bash
   GUIDE="/Users/beomsu/Documents/01. Obsidian/Ataraxia/90. Settings/01 Guideline/Skill Guideline.md"
   test -f "$GUIDE" && echo OK || echo "MISSING: $GUIDE"
   ```
   If missing, the vault's convention is unavailable and the skill cannot be correctly shaped — stop and ask the user to restore the guideline before proceeding.

Run both checks at the top of the run, in parallel. Do not proceed to Capture Intent until both print `OK`.

## Workflow

### 1. Capture intent (from Anthropic skill-creator)

Pull context from the current conversation first. The user may have just run the workflow they want captured, in which case the tools, sequence, inputs, and corrections are already visible — extract them before asking. Confirm:

- What should the skill enable the agent to do?
- When should it trigger? (Gather real user phrases, both Korean and English, for the `description`.)
- What's the expected output?
- Are there objectively verifiable outputs that would benefit from `skill-creator`'s eval loop?

### 2. Read the guideline and the skill-creator

Read both in parallel before writing anything:

- `Ataraxia/90. Settings/01 Guideline/Skill Guideline.md` — the vault's SSOT for naming, structure, publish metadata, and section layout
- `~/.claude/plugins/marketplaces/anthropic-agent-skills/skills/skill-creator/SKILL.md` — process for drafting, testing, and iterating

When the two disagree, the vault Skill Guideline wins. Specifically: **body is English-only**, sections follow the vault layout (Overview / When to Use / Workflow / Common Rationalizations / Red Flags / Verification), and every publishable skill has a `{skill-name}.md` stub with `publish: true`.

### 3. Scaffold the directory

```
50. AI/04 Skills/<skill-name>/
├── SKILL.md                # agent-facing instructions (English)
├── <skill-name>.md         # vault metadata stub (publish: true)
├── references/             # optional, when content > 100 lines
└── scripts/                # optional, for deterministic tools
```

Name rules (from the guideline): `lowercase-hyphen-separated`, no abbreviation, directory name matches `name` frontmatter field.

### 4. Draft SKILL.md

Follow Anthropic's writing patterns (imperative form, progressive disclosure, concrete examples) and the vault's required sections. The `description` frontmatter is the primary trigger — include both *what* and *when*, and add realistic user phrases (English **and** Korean where the skill serves a Korean-speaking user). Keep the description under 1024 characters.

### 5. Write the vault stub

```markdown
---
aliases: []
date_created: <today>
date_modified: <today>
tags: []
type: skill
publish: true
---
```

`publish: true` makes the skill pickable by `skill-deploy`. Leaving it off (or setting `false`) keeps the skill vault-internal.

### 6. Optional: evals

For skills with objectively verifiable outputs (file transforms, data extraction, fixed workflow steps), offer to run Anthropic's eval loop from `skill-creator` to measure triggering accuracy and output quality. Skip for subjective outputs (writing style, design taste) — the iteration cost isn't worth it.

### 7. Hand off

- Point the user at the new skill path
- If `publish: true`, remind them to run `/skill-deploy` to fan out to GitHub + Claude Code plugin + openclaw mirror

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll skip the dependency check — they're usually both there." | When one is missing the skill silently gets wrong structure or the wrong default description. Five seconds of `test -f` catches it up front. |
| "I'll just write the SKILL.md myself, skill-creator is overkill." | skill-creator captures drafting patterns (imperative form, progressive disclosure, description pushiness) that new skills consistently get wrong. Read it for the patterns even if you don't run the full eval loop. |
| "The guideline and skill-creator conflict, so I'll split the difference." | The vault guideline wins on anything the two disagree about (language, sections, metadata). Splitting produces a skill that neither tool can parse cleanly. |
| "I'll inline 200 lines of reference material in SKILL.md." | The guideline caps inline content at 100 lines. Move long material to `references/` so the SKILL.md stays scannable. |
| "I'll forget the `{skill-name}.md` stub — SKILL.md is enough." | `skill-deploy` keys off `publish: true` in the stub. Without it, the skill never leaves the vault. |

## Red Flags

- Starting to write SKILL.md before both dependency checks printed OK
- Directory name that doesn't match the `name` frontmatter field
- Korean sentences in the SKILL.md body (allowed only inside literal example strings)
- Missing `{skill-name}.md` stub or stub without `publish: true` on a skill the user intends to deploy
- `description` that summarizes the workflow steps (the agent ends up following the summary instead of reading the body)
- `description` that only includes English triggers when the user runs a Korean workflow

## Verification

- [ ] Both dependency checks returned OK before any file was written
- [ ] Directory created at `50. AI/04 Skills/<skill-name>/`
- [ ] `SKILL.md` frontmatter `name` matches the directory name
- [ ] `description` covers *what* + *when* and contains the real user phrases
- [ ] SKILL.md body is English-only (Korean allowed only inline inside example strings)
- [ ] `{skill-name}.md` stub exists with `type: skill` and the intended `publish` value
- [ ] Reference files created only when inline content would exceed ~100 lines
- [ ] If `publish: true`, user reminded to run `/skill-deploy`
