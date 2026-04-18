# Multi-Layer Deletion Defense Stack

Three independent layers must be in place before any `ob sync` command runs. They are ordered by how early they catch a destructive action: the earlier the layer, the less state has been mutated when it fires.

## Layer 0 — PreToolUse hook (authoritative block)

**Location:** `.claude/hooks/block-git-dangerous.sh` in the vault repo.

**What it does:** intercepts every Claude Code `Bash` tool call. Parses the JSON tool input, greps the command string against a deny pattern list, and exits with code `2` on a match. Exit 2 is bypass-proof — it blocks even under `bypassPermissions` mode.

**Deny patterns (minimum set):**

```
git add -A
git add --all
git push origin
git push m1pro
git push [^ ]* --force
git push [^ ]* -f( |$)
git push --force
git push -f( |$)
rm -rf
git clean
git rm
```

**Verify:**

```bash
echo '{"tool_input":{"command":"rm -rf x"}}' | .claude/hooks/block-git-dangerous.sh; echo $?
```

Expected output ends with `2`. If it prints `0`, the hook is not matching — check that `python3` is on PATH and the JSON parse step succeeded.

## Layer 1 — Permission deny rules

**Location:** `.claude/settings.json` in the vault repo and in any parent `.claude/settings.json` that Claude Code resolves.

**Critical schema note:** `disableBypassPermissionsMode` must be nested **inside** the `permissions` block, not at the root. Putting it at the root silently fails schema validation in some Claude Code versions; nesting is the correct and forward-compatible form.

```json
{
  "permissions": {
    "disableBypassPermissionsMode": "disable",
    "deny": [
      "Bash(rm *)",
      "Bash(rm -rf *)",
      "Bash(rmdir *)",
      "Bash(git rm *)",
      "Bash(git clean *)",
      "Bash(git add -A)",
      "Bash(git add --all)",
      "Bash(git push origin *)",
      "Bash(git push * --force*)",
      "Bash(git push --force*)",
      "Bash(find * -delete)",
      "Bash(find * -exec rm*)",
      "Bash(find * -exec unlink*)",
      "Bash(shred *)",
      "Bash(trash *)"
    ],
    "allow": []
  }
}
```

**Caveat:** deny rules are read at session start. Adding a rule mid-session is not reliable — restart Claude Code after editing `settings.json`.

## Layer 2 — Pre-commit deletion guard

**Location:** `.git/hooks/pre-commit` inside the vault repo. The hook must be executable and `core.hooksPath` must NOT be set to an alternate directory that does not exist.

**Preflight check (always run):**

```bash
git config --get core.hooksPath
```

If it returns anything, confirm the directory exists. Prefer `git config --unset core.hooksPath` so the default `.git/hooks/` is used — this removes one entire class of silent-disable bug.

**Guard logic (canonical form):**

```bash
#!/bin/bash
THRESHOLD="${DELETE_GUARD_THRESHOLD:-100}"
DELETED=$(git diff --cached --diff-filter=D --name-only 2>/dev/null | grep -c '\.md$')
DELETED="${DELETED:-0}"
if [ "$DELETED" -ge "$THRESHOLD" ]; then
  if [ "$ALLOW_BULK_DELETE" = "1" ]; then
    exit 0
  fi
  echo "[pre-commit] $DELETED md files marked for deletion (threshold: $THRESHOLD)."
  git diff --cached --diff-filter=D --name-only 2>/dev/null | grep '\.md$' | head -10
  echo "To proceed intentionally: ALLOW_BULK_DELETE=1 git commit ..."
  exit 1
fi
exit 0
```

**Key properties:**

- Suffix grep (`grep -c '\.md$'`) — catches nested md files. Do NOT replace with `-- '*.md'` pathspec; that only matches repo root.
- Threshold is environment-overridable (`DELETE_GUARD_THRESHOLD`).
- Bypass is explicit and single-shot (`ALLOW_BULK_DELETE=1`). No permanent opt-out.

## Codex rules (separate agent surface)

Codex has its own deny surface at `~/.codex/rules/default.rules` using `prefix_rule` entries. Keep at least the same ten patterns as Layer 1 (rm, rmdir, git rm, git clean, git add -A, git add --all, git push origin, git push --force, shred, trash).

## Where the locations live

| File | Role |
|---|---|
| `.claude/hooks/block-git-dangerous.sh` | Layer 0 authoritative block |
| `.claude/settings.json` (vault) | Layer 1 deny + bypass disable |
| `.claude/settings.json` (parent dirs) | Layer 1 — resolved in addition to vault |
| `.git/hooks/pre-commit` | Layer 2 bulk deletion guard |
| `~/.codex/rules/default.rules` | Codex-side prefix_rule deny list |
| `.omc/plans/2026-04-18-ataraxia-sync-redesign-ralplan.md` | Source of truth for all of the above |
