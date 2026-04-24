---
name: skill-deploy
description: Push publishable skills from the vault SSOT to GoBeromsu/obsidian-agent-skills on GitHub, then fan out to every runtime declared in each skill's `agent_skill_scope` — Codex CLI (`~/.codex/skills/`), local + m1-pro Claude Code (`agent-skills@beomsu-koh` plugin), m1-pro OpenClaw global pool (`~/.openclaw/skills/`) or xia-main workspace (`~/.openclaw/workspace/skills/`), and m1-pro native Hermes runtime (`~/.hermes/skills/openclaw-imports/`). Use when the user says "/skill-deploy", "스킬 배포", "publish skills", or wants to update any deployed skill surface from the vault SSOT after skill edits.
---

# skill-deploy

## Vault Access

Use the `obsidian-cli` skill for all note creation, edit, search, and property mutation inside the Ataraxia vault. Do not shell out to raw `cat`/`sed` on vault paths. See the `obsidian-cli` SKILL.md for the command surface and required preconditions (Obsidian must be running).

## Overview

Push publishable skills from the vault SSOT to GitHub, then fan out to every downstream surface declared in each skill's `agent_skill_scope` list. The vault copy under `50. AI/04 Skills/Obsidian/` is the source of truth; GitHub, Codex CLI, local + m1-pro Claude Code, m1-pro OpenClaw (global pool or xia-main workspace), and m1-pro native Hermes are mirrors. All surfaces listed on a skill must be updated in the same run, or agents reading from a stale surface will silently drift. See also `[[504.02 Hermes]]`, `[[Hermes Agent]]`, `[[11. Skill Guideline]]`.

## When to Use

- After improving or creating skills in `50. AI/04 Skills/`; after batch edits such as guideline compliance
- When the user explicitly asks to deploy, sync, or publish skills
- Do NOT use before SSOT changes are ready to propagate beyond the vault
- Prerequisites: `gh` authenticated (`gh auth status`), `rsync` available, tailscale reachable on m1-pro

## Deployment Targets

One source, six sinks. Each skill declares which sinks receive it through its `agent_skill_scope` list (see [[11. Skill Guideline]] § agent_skill_scope Target Map). If any declared target fails, the deploy is partial and must be retried.

| # | `agent_skill_scope` value | Target | Transport | Destination | Sync Command |
|---|---|--------|-----------|-------------|--------------|
| 1 | (always) | GitHub SSOT mirror | Branch + PR + squash-merge via `gh` | `GoBeromsu/obsidian-agent-skills` (main), under `skills/<skill>/` | Step 5: `gh pr create` → `gh pr merge --squash --admin` |
| 2 | `claude` | Local Claude Code plugin | `claude plugins update` | `~/.claude/plugins/cache/beomsu-koh/agent-skills/<ver>/skills/<skill>/` | `claude plugins update agent-skills@beomsu-koh` |
| 3 | `claude` | m1-pro Claude Code plugin | ssh over tailscale | same path on m1-pro | `ssh m1-pro claude plugins update agent-skills@beomsu-koh` |
| 4 | `codex` | Local Codex CLI | rsync | `~/.codex/skills/<skill>/` | per-skill `rsync -a --delete` |
| 5 | `codex` | m1-pro Codex CLI | rsync over ssh (tailscale) | `~/.codex/skills/<skill>/` on m1-pro | per-skill `rsync -a --delete` |
| 6 | `openclaw` | m1-pro OpenClaw — global skill pool (all agents) | rsync over ssh (tailscale) | `~/.openclaw/skills/<skill>/` on m1-pro | per-skill `rsync -a --delete` |
| 7 | `openclaw-xia` | m1-pro OpenClaw — **main xia agent only** (workspace-scoped) | rsync over ssh (tailscale) | `~/.openclaw/workspace/skills/<skill>/` on m1-pro | per-skill `rsync -a --delete` |
| 8 | `hermes` | m1-pro native Hermes runtime | rsync over ssh (tailscale) | `~/.hermes/skills/openclaw-imports/<skill>/` on m1-pro | per-skill `rsync -a --delete` |

Target #1 (GitHub) is the SSOT mirror and always runs; every other target is conditional on the presence of its scope value in the skill's `agent_skill_scope`. Skills without `publish: true` are vault-only and filtered in Step 1. Targets #6 and #7 are mutually exclusive — a skill belongs to either the global OpenClaw pool or the xia-only workspace, never both (duplicate registration causes OpenClaw to load the skill twice). Hermes, OpenClaw, and Codex each host sibling skills the vault does not own (e.g., Hermes private skills from `hermes claw migrate`); per-skill `rsync -a --delete` scoped to a single `<skill>/` directory removes only stale files inside that skill, never sibling skills. Full rationale: `references/hermes-target.md`.

## Process

### Step 1 — Scan SSOT

Vault root: `/Users/beomsu/Documents/01. Obsidian/Ataraxia/50. AI/04 Skills/Obsidian/`

For each subdirectory: verify `SKILL.md` exists; check `{skill-name}.md` for `publish: true`; read `agent_skill_scope` (list). Missing `agent_skill_scope` → default to `[claude]` and log `WARN: missing agent_skill_scope, defaulting to [claude]`. Unknown values (anything outside `codex`, `claude`, `openclaw`, `openclaw-xia`, `hermes`) → abort with error. If a stub lists BOTH `openclaw` and `openclaw-xia`, abort with error (mutually exclusive — OpenClaw would load the skill twice).

### Steps 2–5 — Repo prep, copy, version bump, PR

Full bash blocks in `references/hermes-target.md § GitHub deploy runbook`. Key invariants: always `git pull --rebase` before branching; rsync each vault skill into `$REPO/skills/<skill>/` with `--exclude="<skill>.md"` so the vault stub is not published; always bump `.claude-plugin/plugin.json`; use `gh pr merge --squash --admin --delete-branch`; never push directly to `main`. After copying each skill write the scope list: `printf '%s\n' "${scope[@]}" > "$REPO/skills/$skill/.agent_skill_scope"` — Step 6 reads this file.

### Step 6 — Sync Deployed Mirrors

**6a. Claude Code plugins (target #2 + #3, gated on `claude` in scope):**

```bash
claude plugins update agent-skills@beomsu-koh
ssh m1-pro claude plugins update agent-skills@beomsu-koh
```

**6b. Codex CLI — local + m1-pro (targets #4 + #5, gated on `codex` in scope):**

```bash
mkdir -p ~/.codex/skills
ssh m1-pro 'mkdir -p ~/.codex/skills'
for skill in $(ls "$REPO/skills"); do
  grep -qx codex "$REPO/skills/$skill/.agent_skill_scope" || continue
  rsync -a --delete "$REPO/skills/$skill/" "$HOME/.codex/skills/$skill/"
  rsync -a --delete "$REPO/skills/$skill/" "m1-pro:.codex/skills/$skill/"
done
```

**6c. m1-pro OpenClaw global pool (target #6, gated on `openclaw` in scope):**

```bash
for skill in $(ls "$REPO/skills"); do
  grep -qx openclaw "$REPO/skills/$skill/.agent_skill_scope" || continue
  rsync -a --delete "$REPO/skills/$skill/" "m1-pro:.openclaw/skills/$skill/"
done
```

**6c-xia. m1-pro OpenClaw xia-main workspace (target #7, gated on `openclaw-xia` in scope):**

```bash
ssh m1-pro 'mkdir -p ~/.openclaw/workspace/skills'
for skill in $(ls "$REPO/skills"); do
  grep -qx openclaw-xia "$REPO/skills/$skill/.agent_skill_scope" || continue
  rsync -a --delete "$REPO/skills/$skill/" "m1-pro:.openclaw/workspace/skills/$skill/"
done
```

The `~/.openclaw/workspace/` path is the main (`xia`) agent's workspace. Sibling agents (`xia-pkm-roundup`, etc.) use `~/.openclaw/workspace-xia-*/`, so skills landing under `workspace/skills/` are loaded only by main. This is the effective per-agent scoping until OpenClaw ships a first-class `agents.list[].skills` directory convention.

**6d. m1-pro native Hermes runtime (target #8, gated on `hermes` in scope):**

```bash
for skill in $(ls "$REPO/skills"); do
  grep -qx hermes "$REPO/skills/$skill/.agent_skill_scope" || continue
  rsync -a --delete "$REPO/skills/$skill/" "m1-pro:.hermes/skills/openclaw-imports/$skill/"
done
```

### Step 7 — Report

Print deployed/skipped counts for all eight targets. Verify remote: `gh api repos/GoBeromsu/obsidian-agent-skills/contents/skills --jq '.[].name'`.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "The push succeeded so every machine is up to date." | Push updates GitHub only. Every target declared in a skill's `agent_skill_scope` must run its own sync. |
| "I'll edit the deployed plugin cache directly." | Cache is overwritten on next update. Edit the SSOT only. |
| "Plugins update covers Hermes too." | Hermes reads only `~/.hermes/skills/openclaw-imports/`. Without a per-skill rsync it keeps yesterday's skill. |
| "I can rsync at the `~/.hermes/skills/openclaw-imports/` root with `--delete`." | Hermes has private skills alongside vault ones; root-level `--delete` destroys them. Scope each rsync to one `<skill>/` directory. |
| "A skill with missing `agent_skill_scope` should fan out everywhere." | Missing field defaults to `[claude]` only, with a WARN. Silent fan-out risks publishing to a surface the author did not intend. |

## Red Flags

- `git push origin main` directly (blocked by agent policy)
- Pushing without bumping `.claude-plugin/plugin.json` version
- Running `rsync --delete` at a runtime's skills root (`~/.hermes/skills/openclaw-imports/`, `~/.openclaw/skills/`, `~/.openclaw/workspace/skills/`, `~/.codex/skills/`) instead of per-skill — destroys sibling private skills
- Listing both `openclaw` and `openclaw-xia` on the same stub — OpenClaw loads the skill twice (global pool + main workspace)
- Adding a new deployment target without updating the Deployment Targets table and `agent_skill_scope` target map in `[[11. Skill Guideline]]`
- Skipping the Hermes rsync leg because "the plugin update already ran"
- Treating the absence of `agent_skill_scope` as "deploy to everything"
- Publishing the vault stub `{skill-name}.md` into the repo instead of excluding it from the rsync

## Verification

- [ ] Each deployed skill has `publish: true` in its `{skill-name}.md` and a valid `agent_skill_scope` list; `.claude-plugin/plugin.json` bumped
- [ ] PR squash-merged `--admin --delete-branch`; local `main` rebased
- [ ] `claude plugins update agent-skills@beomsu-koh` exits 0 on local and m1-pro for every skill with `claude` in scope
- [ ] Local Codex: `ls ~/.codex/skills/<skill>/SKILL.md` returns path for every skill with `codex` in scope
- [ ] m1-pro Codex: `ssh m1-pro "ls ~/.codex/skills/<skill>/SKILL.md"` returns path for every skill with `codex` in scope
- [ ] OpenClaw (global): `ssh m1-pro "ls ~/.openclaw/skills/<skill>/SKILL.md"` returns path for every skill with `openclaw` in scope
- [ ] OpenClaw (xia-only): `ssh m1-pro "ls ~/.openclaw/workspace/skills/<skill>/SKILL.md"` returns path for every skill with `openclaw-xia` in scope
- [ ] No skill appears in both `~/.openclaw/skills/<skill>/` AND `~/.openclaw/workspace/skills/<skill>/` on m1-pro (mutual exclusion holds)
- [ ] Hermes: `ssh m1-pro "ls ~/.hermes/skills/openclaw-imports/<skill>/SKILL.md"` returns path for every skill with `hermes` in scope
- [ ] Sibling private skills on Hermes / OpenClaw / Codex still present (per-skill `--delete` scope preserved them); deployment report covers all eight targets
