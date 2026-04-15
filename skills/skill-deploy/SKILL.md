---
name: skill-deploy
description: Push publishable skills from vault SSOT to GoBeromsu/agent-skills on GitHub. Use when the user says "/skill-deploy", "스킬 배포", "publish skills", or wants to update deployed skills from the vault SSOT. Also triggers after skill improvements or batch skill edits.
---

# skill-deploy

## Overview

Push publishable skills from vault SSOT to GitHub. GitHub is the single source of truth — each machine pulls updates via `claude plugins update agent-skills@beomsu-koh`.

## When to Use

- After improving or creating skills in `55. Tools/03 Skills/`
- After batch skill edits (guideline compliance, refactoring)
- When the user explicitly asks to deploy, sync, or publish skills
- Do NOT use for individual skill file edits — only for deployment sync

## Prerequisites

`gh` CLI authenticated (`gh auth status`).

## Private Skills Note

Skills without `publish: true` in their metadata are **vault-only** and are not pushed to GitHub. They are not delivered via `claude plugins update`. If needed on non-vault machines, copy manually from the vault SSOT.

| Status | Skills |
|--------|--------|
| `publish: true` (via marketplace) | book, brian-note-challenge, clawhip, deploy-quartz, fyc, gws, obsidian-cli, obsidian-vault-doctor, openclaw, pdf2md, rize, skill-deploy, terminology, youtube-upload, zotero |
| Vault-only (not pushed) | channel-ingest, naver (directories not present in vault) |

## Process

### Step 1 — Scan SSOT

Vault root: `/Users/beomsu/Documents/01. Obsidian/Ataraxia/55. Tools/03 Skills/`

For each subdirectory:
1. Verify `SKILL.md` exists (skip directories without it)
2. Check `{skill-name}/{skill-name}.md` for `publish: true` → mark as GitHub-publishable

### Step 2 — Prepare GitHub Repo

```bash
REPO="${AGENT_SKILLS_REPO_PATH:-$HOME/dev/agent-skills}"

if [ ! -d "$REPO/.git" ]; then
  gh repo view GoBeromsu/agent-skills &>/dev/null || \
    gh repo create GoBeromsu/agent-skills --public --description "Personal Claude Code skill collection"
  gh repo clone GoBeromsu/agent-skills "$REPO"
fi

git -C "$REPO" pull --rebase
```

### Step 3 — Copy Publishable Skills to Repo

For each skill with `publish: true` in its metadata:

```bash
VAULT="/Users/beomsu/Documents/01. Obsidian/Ataraxia/55. Tools/03 Skills"
DEST="$REPO/skills/{skill-name}"
mkdir -p "$DEST"
cp "$VAULT/{skill-name}/SKILL.md" "$DEST/"
for dir in scripts references assets; do
  [ -d "$VAULT/{skill-name}/$dir" ] && cp -r "$VAULT/{skill-name}/$dir/" "$DEST/$dir/"
done
```

Missing `SKILL.md` = error, skip that skill explicitly.

### Step 4 — Commit and Push

```bash
git -C "$REPO" add skills/
git -C "$REPO" diff --cached --quiet && echo "Already up to date." && exit 0
git -C "$REPO" commit -m "deploy: sync skills from vault ($(date +%Y-%m-%d))"
git -C "$REPO" push origin main
```

### Step 5 — Report

```
GitHub Deployed (N):
  ✓ skill-name

GitHub Skipped (M):
  ⊘ skill-name — reason (e.g. publish: false)

To apply on each machine:
  local:   claude plugins update agent-skills@beomsu-koh
  m1-pro:  ssh m1-pro claude plugins update agent-skills@beomsu-koh
```

Verify remote: `gh api repos/GoBeromsu/agent-skills/contents/skills --jq '.[].name'`

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll just run plugins update later, it's fine." | Run it immediately after push. A stale machine is an invisible bug. |
| "The push succeeded so m1-pro is up to date." | Push updates GitHub only. Each machine must explicitly run `claude plugins update`. |
| "I'll edit the deployed plugin cache directly, it's faster." | Plugin cache is overwritten on next `plugins update`. Always edit in `55. Tools/03 Skills/`. |

## Red Flags

- `git push` without `git pull --rebase` first
- `git add .` instead of `git add skills/`
- No deployment summary at the end
- Editing plugin cache copies instead of SSOT (`55. Tools/03 Skills/`)

## Verification

After completing the workflow, confirm:

- [ ] Each GitHub-deployed skill has `publish: true` in its `{skill-name}.md` metadata
- [ ] `git diff --cached --stat` shows only `skills/` paths
- [ ] Remote confirmed: `gh api repos/GoBeromsu/agent-skills/contents/skills --jq '.[].name'`
- [ ] Deployment report printed with deployed/skipped counts
- [ ] `claude plugins update agent-skills@beomsu-koh` exits 0
- [ ] No direct writes to `.claude/skills/` occurred during this run
