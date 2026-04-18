# 2026-04-17 Silent Deletion Incident

This file captures the facts of the incident that motivated the Obsidian Sync bootstrap skill. Read it when a sync change feels low-risk — the history is the counterweight.

## Summary

On 2026-04-17, `ob sync --continuous` v0.0.8 silently deleted approximately **16,692 md files** from the Ataraxia vault. The deletion propagated from a race between the headless daemon and the Obsidian GUI. No layer of defense stopped it at the commit boundary because two independent bugs (see below) silently disabled the pre-commit guard.

The recovery plan lives at `.omc/plans/2026-04-18-ataraxia-sync-redesign-ralplan.md` in the vault and supersedes any older sync documentation.

## Bugs surfaced during the drill

### Bug 1: Pre-commit pathspec

Original pre-commit hook:

```bash
DELETED=$(git diff --cached --diff-filter=D --name-only -- '*.md' 2>/dev/null | wc -l)
```

The `'*.md'` pathspec only matches md files at the repo root, not in nested directories. Any deletion under `folder/*.md` counted as zero, so the threshold guard never fired for real bulk deletions (which are almost always nested).

Fix (suffix grep, applied 2026-04-18 R13):

```bash
DELETED=$(git diff --cached --diff-filter=D --name-only 2>/dev/null | grep -c '\.md$')
```

### Bug 2: `core.hooksPath` misconfig

```
$ git config --get core.hooksPath
/Users/beomsu/Documents/Obsidian/Ataraxia/.git/hooks
```

The path is missing the `01. ` directory prefix. The directory does not exist. Git silently treats the hook as absent, so `pre-commit` was never invoked on any commit, even though the file on disk was correct.

Fix (applied 2026-04-18 R12):

```bash
git config --unset core.hooksPath
```

After unsetting, git resolves hooks from the default `.git/hooks/` directory inside the repo, where the guard actually lives.

**Lesson:** always include `git config --get core.hooksPath` in preflight. A hook file that exists is not the same as a hook that runs.

## Remote vault disappearance

A separate class of failure surfaced on 2026-04-18 during the recovery drill: the old `a615980e…` "Ataraxia" remote vault returned `The connected remote vault no longer exists` on the first `ob sync`. The remote side of the sync had been deleted (likely during the incident or a cleanup that followed). Local files were untouched because `ob sync` failed at the authentication step before any file operations started.

The lesson: **always run `ob sync-list-remote` before `sync-setup` or any mode change**. A remote that you last saw a month ago may not exist today.

## What rolled back vs what was kept

- Local vault content: restored from `safety/pre-redesign-20260418-124711` git tag.
- Defense stack (PreToolUse hook, settings.json deny rules, pre-commit guard, Codex rules): kept and hardened.
- `ob sync` configs on M3 (SSOT machine): removed. M3 uses the Obsidian GUI for sync; only headless replicas run `ob sync`.
- `ob sync` config on M1 (headless replica): repaired to point at the correct local path with device name `m1-pro` and staged in `pull-only` mode pending first-pull verification.

## Why this skill exists

The incident was not caused by a single bug. It was caused by **three simultaneous failures** — a sync tool that didn't fail safe, a pre-commit guard that silently wasn't running, and a pathspec that never matched nested files. Any one of those fixed in isolation would not have stopped the incident.

The bootstrap workflow in `SKILL.md` is designed under the assumption that silent failure is the default. Every step produces evidence, every mode change is staged, and every "safe" assumption is verified.
