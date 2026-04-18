#!/bin/bash
set -euo pipefail
# fix-status-values.sh
# Guideline: 00. Core Guideline §3 — status field must use canonical values
# Canonical: todo, inprogress, done, reviewed, stop
# Fixes: non-canonical status values → nearest canonical value

VAULT="${1:-./Ataraxia}"
VAULT_NAME="$(basename "$VAULT")"
DRY_RUN=false
for arg in "${@:2}"; do [[ "$arg" == "--dry-run" ]] && DRY_RUN=true; done

if ! pgrep -x "Obsidian" > /dev/null 2>&1; then
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "SKIP: Obsidian not running; dry-run skipped for fix-status-values.sh"
        exit 0
    else
        echo "ERROR: Obsidian is not running. Please open Obsidian first." >&2
        exit 1
    fi
fi

echo "=== fix-status-values.sh ==="
echo "Vault: $VAULT"
echo "Dry-run: $DRY_RUN"
echo ""

EXCL_DIRS=(".obsidian" ".trash" ".git" ".omc" ".claude" "_archive" "02 Templates")
FIXED=0
SKIPPED=0
ERRORS=0

FIND_EXCL=()
for d in "${EXCL_DIRS[@]}"; do
    FIND_EXCL+=(-not -path "*/$d/*")
done

normalize_status() {
    local val="$1"
    python3 - "$val" <<'PYEOF'
import sys

val = sys.argv[1].strip().lower()

canonical = {'todo', 'inprogress', 'done', 'reviewed', 'stop'}
mapping = {
    'complete': 'done', 'completed': 'done', 'finished': 'done',
    'in-progress': 'inprogress', 'in progress': 'inprogress', 'wip': 'inprogress',
    'to-do': 'todo', 'inbox': 'todo',
    'cancelled': 'stop', 'canceled': 'stop', 'abandoned': 'stop',
    'active': 'inprogress',
    'ingested': 'done',
}

if val in canonical:
    print("NO_CHANGE")
    sys.exit(0)

normalized = mapping.get(val)
if normalized is None:
    print(f"UNKNOWN:{val}")
    sys.exit(0)

print(normalized)
PYEOF
}

while IFS= read -r -d '' mdfile; do
    rel="${mdfile#"$VAULT/"}"

    status_raw=$(obsidian property:read name="status" path="$rel" vault="$VAULT_NAME" 2>/dev/null || true)
    if [[ -z "$status_raw" ]] || echo "$status_raw" | grep -qi '^Error'; then
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    status_val="${status_raw// /}"  # trim whitespace
    new_status=$(normalize_status "$status_val")

    if [[ "$new_status" == "NO_CHANGE" ]]; then
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    if [[ "$new_status" == UNKNOWN:* ]]; then
        echo "  UNKNOWN status: $rel — '${new_status#UNKNOWN:}'" >&2
        ERRORS=$((ERRORS + 1))
        continue
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [DRY-RUN] Would fix: $rel"
        echo "            status: '$status_val' → '$new_status'"
        FIXED=$((FIXED + 1))
    else
        set_result=$(obsidian property:set name="status" value="$new_status" path="$rel" vault="$VAULT_NAME" 2>/dev/null)
        if echo "$set_result" | grep -qi '^Error'; then
            echo "  ERROR: $rel — $set_result" >&2
            ERRORS=$((ERRORS + 1))
        else
            echo "  FIXED: $rel  ($status_val → $new_status)"
            FIXED=$((FIXED + 1))
        fi
    fi
done < <(find "$VAULT" -name "*.md" "${FIND_EXCL[@]}" -print0)

echo ""
echo "Result: $FIXED fixed, $SKIPPED skipped, $ERRORS errors"
