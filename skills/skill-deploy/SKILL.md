---
name: skill-deploy
description: Push publishable skills from the vault SSOT to GoBeromsu/agent-skills on GitHub, then sync every downstream target — local Claude Code, m1-pro Claude Code, and m1-pro Hermes Docker runtime at `~/.hermes/skills/` (global) or `~/.hermes/agents/xia/workspace/skills/` (xia-scoped) over tailscale. Use when the user says "/skill-deploy", "스킬 배포", "publish skills", or wants to update any deployed skill surface from the vault SSOT after skill edits.
---

# skill-deploy

## Overview

Push publishable skills from the vault SSOT to GitHub, then fan out to every downstream surface. The vault copy under `50. AI/04 Skills/` is the source of truth; GitHub, local Claude Code, m1-pro Claude Code, and m1-pro Hermes (`~/.hermes/skills/`) via Docker are mirrors. All must be updated in the same run, or agents reading from a stale surface will silently drift. See also `[[504.02 Hermes]]`, `[[Hermes Agent]]`, `[[2026-04-21-hermes-skill-pipeline-retarget]]`.

## When to Use

- After improving or creating skills in `50. AI/04 Skills/`; after batch edits such as guideline compliance
- When the user explicitly asks to deploy, sync, or publish skills
- Do NOT use before SSOT changes are ready to propagate beyond the vault
- Prerequisites: `gh` authenticated (`gh auth status`), `rsync` available, tailscale reachable on m1-pro

## Deployment Targets

One source, five sinks. If any target fails, the deploy is partial and must be retried.

| # | Target | Transport | Destination | Sync Command |
|---|--------|-----------|-------------|--------------|
| 1 | GitHub SSOT mirror | Branch + PR + squash-merge via `gh` | `GoBeromsu/agent-skills` (main) | Step 5: `gh pr create` → `gh pr merge --squash --admin` |
| 2 | Local Claude Code plugin | `claude plugins update` | `~/.claude/plugins/cache/beomsu-koh/agent-skills/<ver>/` | `claude plugins update agent-skills@beomsu-koh` |
| 3 | m1-pro Claude Code plugin | ssh over tailscale | same path on m1-pro | `ssh m1-pro claude plugins update agent-skills@beomsu-koh` |
| 4 | m1-pro Hermes global skills | docker cp via ssh (tailscale) | `$HC:/root/.hermes/skills/<skill>/` | per-skill rsync stage → `docker cp` |
| 5 | m1-pro Hermes xia workspace | docker cp via ssh (tailscale) | `$HC:/root/.hermes/agents/xia/workspace/skills/<skill>/` | per-skill rsync stage → `docker cp` |

All five legs are independent. Skills without `publish: true` are vault-only and filtered in Step 1. Hermes has private skills from `hermes claw migrate`; `docker cp` per-skill is the only safe ingress. Full rationale: `references/hermes-target.md`.

## Process

### Step 1 — Scan SSOT

Vault root: `/Users/beomsu/Documents/01. Obsidian/Ataraxia/50. AI/04 Skills/`

For each subdirectory: verify `SKILL.md` exists; check `{skill-name}.md` for `publish: true`; read `deploy_scope` — `global` → target #4, `xia` → target #5, missing → default `global` with WARN.

### Steps 2–5 — Repo prep, copy, version bump, PR

Full bash blocks in `references/hermes-target.md §GitHub deploy runbook`. Key invariants: always `git pull --rebase` before branching; always bump `.claude-plugin/plugin.json`; use `gh pr merge --squash --admin --delete-branch`; never push directly to `main`. After copying each skill write: `echo "$scope" > "$REPO/skills/$skill/.deploy_scope"` — Step 6b reads this file.

### Step 6 — Sync Deployed Mirrors

**6a. Claude Code plugins (targets #2, #3):**

```bash
claude plugins update agent-skills@beomsu-koh
ssh m1-pro claude plugins update agent-skills@beomsu-koh
```

**6b. m1-pro Hermes runtime (targets #4 and #5):**

```bash
HC=$(ssh m1-pro 'docker ps --filter name=hermes --format "{{.Names}}" | head -1')
ssh m1-pro 'mkdir -p ~/.hermes-stage'
for skill in $(ls "$REPO/skills"); do
  scope=$(cat "$REPO/skills/$skill/.deploy_scope" 2>/dev/null || echo global)
  rsync -av --delete "$REPO/skills/$skill/" "m1-pro:.hermes-stage/$skill/"
  if [ "$scope" = "xia" ]; then
    ssh m1-pro "docker cp ~/.hermes-stage/$skill $HC:/root/.hermes/agents/xia/workspace/skills/"
  else
    ssh m1-pro "docker cp ~/.hermes-stage/$skill $HC:/root/.hermes/skills/"
  fi
done
```

Hermes cron CLI fallback and container lifecycle notes: `references/hermes-target.md`.

### Step 7 — Report

Print deployed/skipped counts for all five targets. Verify remote: `gh api repos/GoBeromsu/agent-skills/contents/skills --jq '.[].name'`.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "The push succeeded so every machine is up to date." | Push updates GitHub only. All five targets must run their own sync. |
| "I'll edit the deployed plugin cache directly." | Cache is overwritten on next update. Edit the SSOT only. |
| "Plugins update covers Hermes too." | Hermes reads only `~/.hermes/skills/`. Without `docker cp`, it keeps yesterday's skill. |
| "I'll rsync directly into the running container." | Unreliable across Docker overlayfs. Stage on host first, then `docker cp`. |

## Red Flags

- `git push origin main` directly (blocked by agent policy)
- Pushing without bumping `.claude-plugin/plugin.json` version
- Running `rsync -av --delete` directly into a live container overlayfs without staging on host first
- Adding a new deployment target without updating the Deployment Targets table
- Skipping the Hermes `docker cp` leg because "the plugin update already ran"

## Verification

- [ ] Each deployed skill has `publish: true` in its `{skill-name}.md`; `.claude-plugin/plugin.json` bumped
- [ ] PR squash-merged `--admin --delete-branch`; local `main` rebased
- [ ] `claude plugins update agent-skills@beomsu-koh` exits 0 on local and m1-pro
- [ ] Hermes global: `ssh m1-pro "docker exec $HC ls /root/.hermes/skills/<skill>/SKILL.md"` returns path
- [ ] Hermes xia: `ssh m1-pro "docker exec $HC ls /root/.hermes/agents/xia/workspace/skills/<skill>/SKILL.md"` returns path
- [ ] Hermes-private skills still present; deployment report covers all five targets
