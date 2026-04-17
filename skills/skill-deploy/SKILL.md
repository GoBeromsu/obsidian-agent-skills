---
name: skill-deploy
description: Push publishable skills from the vault SSOT to GoBeromsu/agent-skills on GitHub, then sync every downstream target — local Claude Code, m1-pro Claude Code, and m1-pro openclaw runtime at `~/.openclaw/skills/` over tailscale. Use when the user says "/skill-deploy", "스킬 배포", "publish skills", or wants to update any deployed skill surface from the vault SSOT after skill edits.
---

# skill-deploy

## Overview

Push publishable skills from the vault SSOT to GitHub, then fan out to every downstream surface that consumes them. The vault copy under `50. AI/04 Skills/` is the source of truth; GitHub, local Claude Code, m1-pro Claude Code, and m1-pro openclaw (`~/.openclaw/skills/`) are mirrors. All of them must be updated in the same run, or agents that read from the stale surface will silently drift.

## When to Use

Use this skill only after the SSOT changes are ready to be propagated beyond the vault.

- After improving or creating skills in `50. AI/04 Skills/`
- After batch skill edits such as guideline compliance or refactoring
- When the user explicitly asks to deploy, sync, or publish skills
- Do NOT use for individual skill file edits before the SSOT changes are ready

## Prerequisites

- `gh` CLI authenticated (`gh auth status`)
- `rsync` available locally (preinstalled on macOS)
- Tailscale reachable on m1-pro for the openclaw leg (`tailscale ping m1-pro` responds). If tailscale is down, follow the `tailscale` skill to recover before deploying.

## Deployment Targets

One source, four sinks. Every publishable skill lands on every non-GitHub target in a single run — if any target fails, the deploy is partial and must be retried before closing out.

| # | Target | Transport | Destination | Sync Command |
|---|--------|-----------|-------------|--------------|
| 1 | GitHub SSOT mirror | Branch + PR + squash-merge via `gh` | `GoBeromsu/agent-skills` (main) | Step 5: `gh pr create` → `gh pr merge --squash --admin` |
| 2 | Local Claude Code plugin | `claude plugins update` | `~/.claude/plugins/cache/beomsu-koh/agent-skills/<ver>/` | `claude plugins update agent-skills@beomsu-koh` |
| 3 | m1-pro Claude Code plugin | ssh over tailscale + `claude plugins update` | same path on m1-pro | `ssh m1-pro claude plugins update agent-skills@beomsu-koh` |
| 4 | m1-pro openclaw runtime | `rsync -av --delete` over ssh (tailscale) | `m1-pro:~/.openclaw/skills/<skill-name>/` | per-skill rsync from `$REPO/skills/<skill>/` |

**Why four distinct targets?** Claude Code and openclaw discover skills from different roots. `claude plugins update` only refreshes the plugin cache; it never writes to `~/.openclaw/skills/`. Conversely, rsync to openclaw never updates the plugin cache version string, so Claude Code keeps using the old bundle. Each leg is independent and all four must run.

**Why rsync for openclaw instead of a marketplace?** openclaw classifies skills by `Source`: `openclaw-bundled` (shipped with the CLI), `openclaw-extra` (shipped plugins), `openclaw-managed` (user-owned, in `~/.openclaw/skills/<name>/`), and ClawHub-installed (public marketplace). Our publishable skills are `openclaw-managed` — plain files the user owns. ClawHub's CLI (`openclaw skills install` / `update`) is a read-only consume path for third-party skills; there is no publish command and no local `clawhub` CLI for pushing our SSOT up. Until ClawHub grows a publish API, rsync to `~/.openclaw/skills/` is the correct and only mechanism. Verify any skill we deploy reports `Source: openclaw-managed` via `ssh m1-pro 'openclaw skills info <name>'`.

**Why `--delete` is safe per-skill.** openclaw owns its own private skills (e.g. `agent-log`, `content-fetch`, `article-bzcf-daily`) that are not in the vault. Running `rsync --delete` at the root of `~/.openclaw/skills/` would destroy them. Scoping each rsync to a single `$skill/` directory removes only files inside that skill (stale references, removed assets), never sibling skills.

## Private Skills Note

Skills without `publish: true` in their `{skill-name}.md` metadata are **vault-only**. Step 1's scan filters them out automatically — no hardcoded allow/deny list is maintained here, because any static list rots the moment a new skill lands or an old one flips `publish`. The live SSOT for "what shipped this run" is Step 7's report; for "what is currently publishable" it is the Step 1 scan over the vault. If a vault-only skill is needed on a non-vault machine, copy it manually from the vault SSOT.

## Process

### Step 1 — Scan SSOT

Vault root: `/Users/beomsu/Documents/01. Obsidian/Ataraxia/50. AI/04 Skills/`

For each subdirectory:
1. Verify `SKILL.md` exists (skip directories without it)
2. Check `{skill-name}/{skill-name}.md` for `publish: true` and mark it as GitHub-publishable

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
VAULT="/Users/beomsu/Documents/01. Obsidian/Ataraxia/50. AI/04 Skills"
DEST="$REPO/skills/{skill-name}"
mkdir -p "$DEST"
cp "$VAULT/{skill-name}/SKILL.md" "$DEST/"
for dir in scripts references assets; do
  [ -d "$VAULT/{skill-name}/$dir" ] && cp -r "$VAULT/{skill-name}/$dir/" "$DEST/$dir/"
done
```

Missing `SKILL.md` is an error. Skip that skill explicitly and report it.

### Step 4 — Version Bump

`claude plugins update` compares version strings, so the version must change when deployed content changes.

```bash
PLUGIN_JSON="$REPO/.claude-plugin/plugin.json"
CURRENT=$(grep -o '"version": "[^"]*"' "$PLUGIN_JSON" | grep -o '[0-9]*\.[0-9]*\.[0-9]*')
MAJOR=$(echo "$CURRENT" | cut -d. -f1)
MINOR=$(echo "$CURRENT" | cut -d. -f2)
PATCH=$(echo "$CURRENT" | cut -d. -f3)
NEW_VERSION="$MAJOR.$MINOR.$((PATCH + 1))"
sed -i '' "s/\"version\": \"$CURRENT\"/\"version\": \"$NEW_VERSION\"/" "$PLUGIN_JSON"
echo "Version: $CURRENT → $NEW_VERSION"
```

### Step 5 — Branch, Commit, PR, Merge

Direct push to `main` is blocked by agent policy ("Git Push to Default Branch" guardrail), so every deploy ships through a throwaway PR. The repo itself has no branch protection, so `gh pr merge --squash --admin` closes the loop immediately without waiting for a reviewer. The PR exists for the audit trail, not for human review.

```bash
BRANCH="deploy/$(date +%Y%m%d-%H%M%S)"
git -C "$REPO" checkout -b "$BRANCH"
git -C "$REPO" add skills/ .claude-plugin/plugin.json
git -C "$REPO" diff --cached --quiet && { echo "Already up to date."; git -C "$REPO" checkout main; git -C "$REPO" branch -D "$BRANCH"; exit 0; }
git -C "$REPO" commit -m "deploy: sync skills from vault ($(date +%Y-%m-%d))"
git -C "$REPO" push -u origin "$BRANCH"

PR_URL=$(gh pr create --repo GoBeromsu/agent-skills \
  --title "deploy: sync skills from vault ($(date +%Y-%m-%d))" \
  --body "Automated deploy from skill-deploy. See commits for details." \
  --base main --head "$BRANCH")
echo "Opened $PR_URL"

gh pr merge "$PR_URL" --squash --admin --delete-branch
git -C "$REPO" checkout main
git -C "$REPO" pull --rebase
```

**Why `--admin`?** The repo is personal, unprotected, and single-maintainer. There is no reviewer to wait on and the deploy is stalled without an admin override. If the repo ever gains branch protection (required reviews, required checks), drop `--admin` and block on review before proceeding to Step 6.

**Why `--delete-branch`?** Keeps the branch list clean. The squash-merged content is already on `main`.

### Step 6 — Sync Deployed Mirrors

Run all three non-GitHub targets from §Deployment Targets. Treat any non-zero exit as a failed deploy that must be retried — do not proceed to the report until every target is green.

**6a. Claude Code plugins (targets #2, #3):**

```bash
claude plugins update agent-skills@beomsu-koh
ssh m1-pro claude plugins update agent-skills@beomsu-koh
```

**6b. m1-pro openclaw runtime (target #4):**

Before the first deploy, ensure the destination root exists:

```bash
ssh m1-pro 'mkdir -p ~/.openclaw/skills'
```

Then rsync each publishable skill individually. `--delete` is scoped to the per-skill directory so openclaw-private skills on m1-pro are never touched:

```bash
for skill in $(ls "$REPO/skills"); do
  rsync -av --delete \
    "$REPO/skills/$skill/" \
    "m1-pro:.openclaw/skills/$skill/"
done
```

Iterate over the subdirectory list of `$REPO/skills/` (which already contains only publishable skills filtered in Step 3). Never rsync the `$REPO/skills/` root with `--delete` — that would wipe openclaw-private skills.

Additional machines join here only when they actually consume one of the two runtimes (plugin cache or openclaw). Add them to §Deployment Targets first so the table stays the single source of truth.

### Step 7 — Report

```text
GitHub Deployed (N):
  ✓ skill-name

GitHub Skipped (M):
  ⊘ skill-name — reason (e.g. publish: false)

Mirror Sync:
  ✓ local           (claude plugins update)
  ✓ m1-pro plugin   (ssh claude plugins update)
  ✓ m1-pro openclaw (rsync → ~/.openclaw/skills/)
```

Verify remote: `gh api repos/GoBeromsu/agent-skills/contents/skills --jq '.[].name'`
Verify openclaw: `ssh m1-pro 'ls ~/.openclaw/skills/<a-deployed-skill>/SKILL.md && head -1 ~/.openclaw/skills/<a-deployed-skill>/SKILL.md'` — confirm the file exists and its frontmatter header matches the vault copy.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll just run plugins update later, it's fine." | Run it immediately after push. A stale machine is an invisible bug. |
| "The push succeeded so every machine is up to date." | Push updates GitHub only. Each target in §Deployment Targets must run its own sync command. |
| "I'll edit the deployed plugin cache directly, it's faster." | Plugin cache is overwritten on the next update. Always edit the SSOT in `50. AI/04 Skills/`. |
| "I pushed to GitHub so `plugins update` will pick it up automatically." | `plugins update` compares version strings only. Same version means no download. Always bump `.claude-plugin/plugin.json` before pushing. |
| "openclaw reads from the plugin cache too, so `plugins update` covers it." | openclaw reads only from `~/.openclaw/skills/`. Without the rsync leg, openclaw keeps running yesterday's skill. |
| "I'll just rsync the whole `$REPO/skills/` tree with `--delete` to the openclaw root." | That deletes openclaw-private skills (`agent-log`, `content-fetch`, etc.). Always iterate per-skill. |

## Red Flags

These patterns usually mean the deployment is drifting away from a clean SSOT-first sync.

- `git push origin main` directly (blocked by agent policy; use the branch + PR flow from Step 5)
- Opening a PR without `gh pr merge --squash --admin` — leaves deploy half-done
- `git add .` instead of `git add skills/ .claude-plugin/plugin.json`
- Pushing without bumping `.claude-plugin/plugin.json` version
- Skipping `git -C "$REPO" pull --rebase` on `main` after merge (stale local main triggers the next deploy's merge conflict)
- No deployment summary at the end
- Editing plugin cache copies instead of the SSOT under `50. AI/04 Skills/`
- Skipping the openclaw rsync leg because "the plugin update already ran"
- Running `rsync --delete` against `~/.openclaw/skills/` root instead of per-skill subdirectories
- Adding a new deployment target by editing only Step 6, without updating the §Deployment Targets table

## Verification

After completing the workflow, confirm:

- [ ] Each GitHub-deployed skill has `publish: true` in its `{skill-name}.md` metadata
- [ ] `.claude-plugin/plugin.json` version was incremented
- [ ] `git diff --cached --stat` shows `skills/` and `.claude-plugin/plugin.json` paths only
- [ ] PR opened, squash-merged with `--admin --delete-branch`, and local `main` rebased on origin
- [ ] Remote confirmed: `gh api repos/GoBeromsu/agent-skills/contents/skills --jq '.[].name'`
- [ ] Deployment report printed with deployed/skipped counts covering all four targets
- [ ] `claude plugins update agent-skills@beomsu-koh` exits 0 on local and m1-pro
- [ ] m1-pro openclaw: `ssh m1-pro 'ls ~/.openclaw/skills/<one-deployed-skill>/SKILL.md'` returns the path (file exists, post-rsync)
- [ ] m1-pro openclaw: openclaw-private skills (e.g. `agent-log`) still present — rsync did not wipe them
- [ ] No direct writes to deployed plugin cache copies or to `~/.openclaw/skills/` outside this skill's rsync step
