#!/bin/bash
set -euo pipefail
# verify-eval-engine.sh — lint skill eval-engine preflight.
# Runs 4 checks; exits 1 with a named failure on any failure, 0 when all pass.
# Checks 2 and 3 require Obsidian running. Check 4 is pure filesystem.
# Usage: bash lint/scripts/verify-eval-engine.sh

echo "=== verify-eval-engine.sh: eval engine preflight ==="
echo ""

echo "[1/4] Checking obsidian-cli availability..."
if ! command -v obsidian > /dev/null 2>&1; then
    echo "FAIL [Check 1]: 'obsidian' command not found in PATH." >&2
    echo "  Install with: npm install -g @obsidianmd/obsidian-cli" >&2
    exit 1
fi
OBSIDIAN_PATH="$(command -v obsidian)"
echo "  OK: obsidian found at $OBSIDIAN_PATH"
echo ""

echo "[2/4] Checking obsidian eval ping..."
PING_RESULT="$(obsidian eval code="'ping'" 2>/dev/null | sed 's/^=> //' | tr -d '[:space:]' || true)"
if [[ "$PING_RESULT" != "ping" ]]; then
    echo "FAIL [Check 2]: obsidian eval ping failed." >&2
    echo "  Expected: ping" >&2
    echo "  Got:      ${PING_RESULT:-(empty)}" >&2
    echo "  Is Obsidian running? Is obsidian-cli connected to the vault?" >&2
    exit 1
fi
echo "  OK: eval ping returned 'ping'"
echo ""

echo "[3/4] Checking obsidian-linter plugin is enabled..."
LINTER_ENABLED="$(obsidian eval code="app.plugins.enabledPlugins.has('obsidian-linter')" 2>/dev/null | sed 's/^=> //' | tr -d '[:space:]' || true)"
if [[ "$LINTER_ENABLED" != "true" ]]; then
    echo "FAIL [Check 3]: obsidian-linter plugin is not enabled." >&2
    echo "  Expected: true" >&2
    echo "  Got:      ${LINTER_ENABLED:-(empty)}" >&2
    echo "  Enable it in Obsidian Settings > Community Plugins > obsidian-linter." >&2
    exit 1
fi
echo "  OK: obsidian-linter plugin is enabled"
echo ""

echo "[4/4] Sandbox dry-run of fix-yaml-delimiters.sh on a sample violating file..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SANDBOX_DIR="$(mktemp -d)"
SAMPLE_FILE="$SANDBOX_DIR/sample_violation.md"

cat > "$SAMPLE_FILE" << 'SAMPLE'
-----
name: test
tags:
  - test
-----
Body text.
SAMPLE

ORIGINAL_HASH="$(md5 -q "$SAMPLE_FILE" 2>/dev/null || md5sum "$SAMPLE_FILE" | awk '{print $1}')"

DRY_RUN_OUTPUT="$(bash "$SCRIPT_DIR/fix-yaml-delimiters.sh" "$SANDBOX_DIR" --dry-run 2>&1 || true)"

AFTER_HASH="$(md5 -q "$SAMPLE_FILE" 2>/dev/null || md5sum "$SAMPLE_FILE" | awk '{print $1}')"

if [[ "$ORIGINAL_HASH" != "$AFTER_HASH" ]]; then
    echo "FAIL [Check 4]: fix-yaml-delimiters.sh --dry-run mutated the sample file." >&2
    echo "  The fix script is not honoring --dry-run." >&2
    rm -rf "$SANDBOX_DIR"
    exit 1
fi

if ! echo "$DRY_RUN_OUTPUT" | grep -q "\[DRY-RUN\]"; then
    echo "FAIL [Check 4]: fix-yaml-delimiters.sh --dry-run did not report any would-fix output." >&2
    echo "  The script may not be detecting the 5-dash violation." >&2
    echo "  Dry-run output was:" >&2
    echo "$DRY_RUN_OUTPUT" >&2
    rm -rf "$SANDBOX_DIR"
    exit 1
fi

rm -rf "$SANDBOX_DIR"
echo "  OK: dry-run detected violation, original file untouched"
echo ""

echo "=== All 4 preflight checks PASSED. Eval engine is healthy. ==="
exit 0
