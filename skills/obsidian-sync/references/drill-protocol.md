# Defense Stack Verification Drill

Run this drill after any change to the hooks, deny rules, or pre-commit guard. It takes about five minutes and produces direct evidence that each layer actually blocks a bulk deletion.

## Preconditions

- The vault is in a clean state (`git status` is clean, or at minimum there are no staged deletions).
- A safety tag exists (`git tag | grep safety/`).
- You know how to force-exit in case the drill triggers an unexpected action (`Ctrl+C`, kill tmux, etc.).

## Drill 1: Layer 0 (PreToolUse hook) direct-pipe

This tests the hook itself, without involving Claude Code. It proves the exit-2 behaviour works for piped deletion-class commands.

```bash
HOOK=".claude/hooks/block-git-dangerous.sh"
for CMD in \
  'rm -rf test' \
  'git rm -r foo/' \
  'git add -A' \
  'git push origin main'; do
  OUT=$(printf '{"tool_input":{"command":"%s"}}' "$CMD" | "$HOOK" 2>&1)
  RC=$?
  echo "cmd=[$CMD] rc=$RC out=$OUT"
done
```

Expected: every iteration prints `rc=2` and an `out=BLOCKED by block-git-dangerous.sh: matched pattern '...'` line.

## Drill 2: Layer 2 (pre-commit guard) nested bulk deletion

This verifies the pre-commit guard blocks ≥ threshold md deletions at nested paths. Run on a throwaway branch so nothing actually changes on your working branch.

```bash
BRANCH="drill/pre-commit-$(date +%s)"
THRESHOLD=100
TARGET_DIR=".omc/drill-targets"

git checkout -b "$BRANCH"
mkdir -p "$TARGET_DIR"
for i in $(seq 1 101); do
  echo "drill $i" > "$TARGET_DIR/drill_$i.md"
done
git add "$TARGET_DIR"
git commit -m "drill: add $((THRESHOLD + 1)) drill targets"

# Stage deletions
git rm -r "$TARGET_DIR" > /dev/null

# Attempt commit — must fail
git commit -m "drill: delete all targets (should be blocked)" 2>&1 | tee /tmp/drill-pre-commit.log
echo "commit rc=$?"
```

Expected: the commit fails, the log contains `[pre-commit] 101 md files marked for deletion (threshold: 100).`, and `commit rc=1`.

Cleanup:

```bash
git reset --hard HEAD~1
git checkout -
git branch -D "$BRANCH"
```

## Drill 3: Layer 2 smoke test (small deletion must pass)

The guard must NOT block legitimate small edits. Stage and commit a 2-file deletion on a throwaway branch and confirm it succeeds.

```bash
BRANCH="drill/smoke-$(date +%s)"
git checkout -b "$BRANCH"
mkdir -p .omc/drill-smoke
for i in 1 2; do echo smoke > .omc/drill-smoke/s_$i.md; done
git add .omc/drill-smoke && git commit -m "drill: add 2 smoke files"
git rm -r .omc/drill-smoke > /dev/null
git commit -m "drill: delete 2 smoke files" 2>&1
echo "commit rc=$?"

# Cleanup
git reset --hard HEAD~1
git checkout -
git branch -D "$BRANCH"
```

Expected: `commit rc=0`, no block message.

## Drill 4: `core.hooksPath` sanity

Before and after any change to hook config, confirm:

```bash
git config --get core.hooksPath
ls -la .git/hooks/pre-commit
```

Expected: either no output (default hook path) or a path that actually exists; and `pre-commit` exists and is executable.

## Drill 5: Codex prefix_rule sanity

```bash
grep -c '^deny ' ~/.codex/rules/default.rules
```

Expected: at least `10` matching deny entries covering rm, rmdir, git rm, git clean, git add -A, git add --all, git push origin, git push --force, shred, trash.

## Reporting template

Store drill evidence in `.omc/logs/drill-report-<timestamp>.md` using this shape:

```
# Defense Drill <timestamp>
- Layer 0: 4/4 deny patterns returned rc=2 ✓
- Layer 2 bulk: 101 md staged, commit blocked with threshold message ✓
- Layer 2 smoke: 2 md staged, commit succeeded ✓
- core.hooksPath: <value or "unset">
- Codex prefix_rule deny count: <n>
- Verdict: PASS | FAIL (and which layer failed)
```

Every drill report entry should be an atomic commit so it becomes part of the local snapshot history.
