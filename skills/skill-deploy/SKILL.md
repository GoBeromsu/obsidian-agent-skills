---
name: skill-deploy
description: Push publishable skills from the vault SSOT to GoBeromsu/obsidian-agent-skills on GitHub, then fan out to every runtime declared in each skill's `agent_skill_scope` — Codex CLI (`~/.codex/skills/`), local + m1-pro Claude Code (`~/.claude/skills/Obsidian/`), m1-pro OpenClaw workspace, and m1-pro Hermes Docker runtime (`~/.hermes/skills/`). Use when the user says "/skill-deploy", "스킬 배포", "publish skills", or wants to update any deployed skill surface from the vault SSOT after skill edits.
---

# skill-deploy

## Vault Access

Use the `obsidian-cli` skill for all note creation, edit, search, and property mutation inside the Ataraxia vault. Do not shell out to raw `cat`/`sed` on vault paths. See the `obsidian-cli` SKILL.md for the command surface and required preconditions (Obsidian must be running).

## Overview

Push publishable skills from the vault SSOT to GitHub, then fan out to every downstream surface declared in each skill's `agent_skill_scope` list. The vault copy under `50. AI/04 Skills/Obsidian/` is the source of truth; GitHub, Codex CLI, local + m1-pro Claude Code, m1-pro OpenClaw, and m1-pro Hermes Docker are mirrors. All surfaces listed on a skill must be updated in the same run, or agents reading from a stale surface will silently drift. See also `[[504.02 Hermes]]`, `[[Hermes Agent]]`, `[[11. Skill Guideline]]`.

## When to Use

- After improving or creating skills in `50. AI/04 Skills/`; after batch edits such as guideline compliance
- When the user explicitly asks to deploy, sync, or publish skills
- Do NOT use before SSOT changes are ready to propagate beyond the vault
- Prerequisites: `gh` authenticated (`gh auth status`), `rsync` available, tailscale reachable on m1-pro

## Deployment Targets

One source, five sinks. Each skill declares which sinks receive it through its `agent_skill_scope` list (see [[11. Skill Guideline]] § agent_skill_scope Target Map). If any declared target fails, the deploy is partial and must be retried.

| # | `agent_skill_scope` value | Target | Transport | Destination | Sync Command |
|---|---|--------|-----------|-------------|--------------|
| 1 | (always) | GitHub SSOT mirror | Branch + PR + squash-merge via `gh` | `GoBeromsu/obsidian-agent-skills` (main), under `skills/Obsidian/` | Step 5: `gh pr create` → `gh pr merge --squash --admin` |
| 2 | `claude` | Local Claude Code plugin | `claude plugins update` | `~/.claude/skills/Obsidian/<skill>/` | `claude plugins update obsidian-agent-skills@beomsu-koh` |
| 3 | `claude` | m1-pro Claude Code plugin | ssh over tailscale | same path on m1-pro | `ssh m1-pro claude plugins update obsidian-agent-skills@beomsu-koh` |
| 4 | `codex` | Codex CLI | rsync | `~/.codex/skills/<skill>/` | `rsync -av --delete "$VAULT/<skill>/" ~/.codex/skills/<skill>/` |
| 5 | `openclaw` | m1-pro OpenClaw workspace | rsync over ssh (tailscale) | OpenClaw skills path on m1-pro (managed by the `openclaw` skill) | per-skill rsync |
| 6 | `hermes` | m1-pro Hermes global skills | docker cp via ssh (tailscale) | `$HC:/root/.hermes/skills/<skill>/` | per-skill rsync stage → `docker cp` |

Target #1 (GitHub) is the SSOT mirror and always runs; every other target is conditional on the presence of its scope value in the skill's `agent_skill_scope`. Skills without `publish: true` are vault-only and filtered in Step 1. Hermes has private skills from `hermes claw migrate`; `docker cp` per-skill is the only safe ingress. Full rationale: `references/hermes-target.md`.

## Process

### Step 1 — Scan SSOT

Vault root: `/Users/beomsu/Documents/01. Obsidian/Ataraxia/50. AI/04 Skills/Obsidian/`

For each subdirectory: verify `SKILL.md` exists; check `{skill-name}.md` for `publish: true`; read `agent_skill_scope` (list). Missing `agent_skill_scope` → default to `[claude]` and log `WARN: missing agent_skill_scope, defaulting to [claude]`. Unknown values (anything outside `codex`, `claude`, `openclaw`, `hermes`) → abort with error.

### Steps 2–5 — Repo prep, copy, version bump, PR

Full bash blocks in `references/hermes-target.md § GitHub deploy runbook`. Key invariants: always `git pull --rebase` before branching; copy each skill into `$REPO/skills/Obsidian/<skill>/`; always bump `.claude-plugin/plugin.json`; use `gh pr merge --squash --admin --delete-branch`; never push directly to `main`. After copying each skill write the scope list: `printf '%s\n' "${scope[@]}" > "$REPO/skills/Obsidian/$skill/.agent_skill_scope"` — Step 6 reads this file.

### Step 6 — Sync Deployed Mirrors

**6a. Claude Code plugins (target #2 + #3, gated on `claude` in scope):**

```bash
claude plugins update obsidian-agent-skills@beomsu-koh
ssh m1-pro claude plugins update obsidian-agent-skills@beomsu-koh
```

**6b. Codex CLI (target #4, gated on `codex` in scope):**

```bash
mkdir -p ~/.codex/skills
for skill in $(ls "$REPO/skills/Obsidian"); do
  grep -qx codex "$REPO/skills/Obsidian/$skill/.agent_skill_scope" || continue
  rsync -av --delete "$REPO/skills/Obsidian/$skill/" "$HOME/.codex/skills/$skill/"
done
```

**6c. m1-pro OpenClaw workspace (target #5, gated on `openclaw` in scope):** follow the `openclaw` skill for the current workspace path; deploy per-skill rsync after confirming the OpenClaw gateway is healthy.

**6d. m1-pro Hermes runtime (target #6, gated on `hermes` in scope):**

```bash
HC=$(ssh m1-pro 'docker ps --filter name=hermes --format "{{.Names}}" | head -1')
ssh m1-pro 'mkdir -p ~/.hermes-stage'
for skill in $(ls "$REPO/skills/Obsidian"); do
  grep -qx hermes "$REPO/skills/Obsidian/$skill/.agent_skill_scope" || continue
  rsync -av --delete "$REPO/skills/Obsidian/$skill/" "m1-pro:.hermes-stage/$skill/"
  ssh m1-pro "docker cp ~/.hermes-stage/$skill $HC:/root/.hermes/skills/"
done
```

Hermes cron CLI fallback and container lifecycle notes: `references/hermes-target.md`.

### Step 7 — Report

Print deployed/skipped counts for all six targets. Verify remote: `gh api repos/GoBeromsu/obsidian-agent-skills/contents/skills/Obsidian --jq '.[].name'`.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "The push succeeded so every machine is up to date." | Push updates GitHub only. Every target declared in a skill's `agent_skill_scope` must run its own sync. |
| "I'll edit the deployed plugin cache directly." | Cache is overwritten on next update. Edit the SSOT only. |
| "Plugins update covers Hermes too." | Hermes reads only `~/.hermes/skills/`. Without `docker cp`, it keeps yesterday's skill. |
| "I'll rsync directly into the running container." | Unreliable across Docker overlayfs. Stage on host first, then `docker cp`. |
| "A skill with missing `agent_skill_scope` should fan out everywhere." | Missing field defaults to `[claude]` only, with a WARN. Silent fan-out risks publishing to a surface the author did not intend. |

## Red Flags

- `git push origin main` directly (blocked by agent policy)
- Pushing without bumping `.claude-plugin/plugin.json` version
- Running `rsync -av --delete` directly into a live container overlayfs without staging on host first
- Adding a new deployment target without updating the Deployment Targets table and `agent_skill_scope` target map in `[[11. Skill Guideline]]`
- Skipping the Hermes `docker cp` leg because "the plugin update already ran"
- Treating the absence of `agent_skill_scope` as "deploy to everything"

## Verification

- [ ] Each deployed skill has `publish: true` in its `{skill-name}.md` and a valid `agent_skill_scope` list; `.claude-plugin/plugin.json` bumped
- [ ] PR squash-merged `--admin --delete-branch`; local `main` rebased
- [ ] `claude plugins update obsidian-agent-skills@beomsu-koh` exits 0 on local and m1-pro for every skill with `claude` in scope
- [ ] Codex surface: `ls ~/.codex/skills/<skill>/SKILL.md` returns path for every skill with `codex` in scope
- [ ] OpenClaw surface: skill present in the OpenClaw workspace for every skill with `openclaw` in scope
- [ ] Hermes global: `ssh m1-pro "docker exec $HC ls /root/.hermes/skills/<skill>/SKILL.md"` returns path for every skill with `hermes` in scope
- [ ] Hermes-private skills still present; deployment report covers all six targets
