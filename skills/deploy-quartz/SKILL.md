---
name: deploy-quartz
description: Use when you need to publish Obsidian notes to the Quartz static site at berom.net, including staging content, Eagle image processing, building, and git push.
---

# Deploy Quartz

## Overview

This skill deploys Obsidian notes to the Quartz static site at `berom.net`. The Blog repository path is read from `QUARTZ_REPO_PATH` in the Ataraxia vault `.env` file. Articles go directly into `content/Articles/`. Eagle image processing runs only when `file:///` paths are detected.

The AI's role is to invoke `scripts/deploy.sh` and report results. All complex logic lives in the script.

## When to Use

- Use when the user says "배포", "배포해줘", "deploy", "publish", "/deploy-quartz", "/deploy", "사이트에 올려줘", "블로그에 발행", or wants to push content to `berom.net`.
- Use when the user provides a specific note path and asks to deploy it.
- Do not use for Tistory or Naver blog publishing.

## Process

### Configuration

All configuration is loaded from `.env` at the Ataraxia vault root.

| Variable | Description | Value |
|---|---|---|
| `QUARTZ_REPO_PATH` | Blog vault (Quartz repo) path | Set in `.env` |
| `EAGLE_LIBRARY_PATH` | Eagle library path | Set in `.env` |
| `DEPLOY_SITE_URL` | Site URL | `https://berom.net` |
| `DEPLOY_GIT_BRANCH` | Git branch | `v5` |
| `DEPLOY_GIT_REMOTE` | Git remote | `origin` |

Validate `QUARTZ_REPO_PATH` is set and the path exists before proceeding. It can go stale after directory reorganization.

### Single File Deploy (most common)

When the user specifies a file to deploy:

```bash
# Load config
source "/Users/beomsu/Documents/01. Obsidian/Ataraxia/.env"

# Copy to content directory
cp "NOTE_FILE.md" "$QUARTZ_REPO_PATH/content/Articles/"

# Process Eagle images if needed (only if file:/// paths present)
cd "$QUARTZ_REPO_PATH"
node "55. Tools/03 Skills/deploy-quartz/scripts/process-eagle-images.mjs"

# Build
npx quartz build

# Stage ONLY content and attachments — NEVER git add .
git add content/
git add _attachments/

git commit -m "feat: add Article Name"
git push origin v5
```

### Full Deploy (via script)

```bash
"55. Tools/03 Skills/deploy-quartz/scripts/deploy.sh"
```

The `deploy.sh` script handles:
1. `.env` config loading
2. Eagle image processing (skipped if no `file:///` paths found)
3. Quartz build via `npx quartz build`
4. Selective `git add content/` + `git add _attachments/`
5. Auto-generated commit message and push to `origin v5`

For staging-specific preparation, use `prepare-staging.sh` before `deploy.sh`.

### Eagle Image Processing

Only runs when markdown files contain Eagle `file:///` paths. The `process-eagle-images.mjs` script:
- Scans content for Eagle image references
- Copies images from the Eagle library to `_attachments/`
- Rewrites markdown paths to use relative `/_attachments/` paths

Plain markdown without Eagle paths skips this step entirely.

### On Success

Report to user:
- Commit hash and message
- "배포 완료!" confirmation
- Site URL: `https://berom.net`

### On Failure

```bash
cd "$QUARTZ_REPO_PATH" && git revert HEAD --no-edit && git push origin v5
```

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "`git add .` is faster and I know what I'm committing." | Broad staging sweeps in `.omc/`, `AGENTS.md`, build artifacts, and other local noise into the deploy commit. |
| "Asset processing can always run — it won't hurt if there are no Eagle paths." | Conditional processing is explicit. Unconditional processing masks errors when the Eagle library path is stale. |
| "The branch is probably still v5, no need to check." | `DEPLOY_GIT_BRANCH` is the source of truth. Hardcoding the branch causes silent pushes to the wrong branch after config changes. |

## Red Flags

- `git add .` anywhere in the deploy workflow — only `git add content/` and `git add _attachments/` are allowed.
- Pushing without running `npx quartz build` first — build errors must block the push.
- Not loading `.env` before accessing `QUARTZ_REPO_PATH` — the path will be empty and the deploy will silently fail or corrupt the wrong directory.
- Skipping the empty-diff check — committing with nothing staged creates an empty commit.

## Verification

- [ ] `.env` loaded and `QUARTZ_REPO_PATH` resolves to an existing directory.
- [ ] Only `content/` and `_attachments/` staged — confirmed with `git diff --cached --name-only`.
- [ ] `npx quartz build` exits 0 before `git push`.
- [ ] Commit hash, branch (`v5`), and site URL (`https://berom.net`) reported to user.
- [ ] If `git diff --cached` is empty after staging, inform user the site is already up to date instead of creating an empty commit.
