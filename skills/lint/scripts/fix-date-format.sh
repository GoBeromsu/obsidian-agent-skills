#!/bin/bash
set -euo pipefail
# fix-date-format.sh
# Guideline: 00. Core Guideline §3 — date_created must be YYYY-MM-DD (date type, not datetime)
# Fixes: datetime values like "2024-01-01T12:34:56" or "2024-01-01 12:34:56" → "2024-01-01"

VAULT="${1:-./Ataraxia}"
VAULT_NAME="$(basename "$VAULT")"
DRY_RUN=false
for arg in "${@:2}"; do [[ "$arg" == "--dry-run" ]] && DRY_RUN=true; done

if ! pgrep -x "Obsidian" > /dev/null 2>&1; then
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "SKIP: Obsidian not running; dry-run skipped for fix-date-format.sh"
        exit 0
    else
        echo "ERROR: Obsidian is not running. Please open Obsidian first." >&2
        exit 1
    fi
fi

echo "=== fix-date-format.sh ==="
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

extract_date() {
    local val="$1"
    python3 - "$val" <<'PYEOF'
import sys, re

val = sys.argv[1].strip()

# Already a plain date: YYYY-MM-DD
if re.match(r'^\d{4}-\d{2}-\d{2}$', val):
    print("NO_CHANGE")
    sys.exit(0)

# datetime with T separator: 2024-01-01T12:34:56
m = re.match(r'^(\d{4}-\d{2}-\d{2})[T ]', val)
if m:
    print(m.group(1))
    sys.exit(0)

# Timestamp (unix epoch) — convert to date
if re.match(r'^\d{10,13}$', val):
    import datetime
    ts = int(val)
    if ts > 1e10:
        ts = ts / 1000  # milliseconds
    d = datetime.datetime.utcfromtimestamp(ts).strftime('%Y-%m-%d')
    print(d)
    sys.exit(0)

print("NO_CHANGE")
PYEOF
}

while IFS= read -r -d '' mdfile; do
    rel="${mdfile#"$VAULT/"}"

    date_raw=$(obsidian property:read name="date_created" path="$rel" vault="$VAULT_NAME" 2>/dev/null || true)
    if [[ -z "$date_raw" ]] || echo "$date_raw" | grep -qi '^Error'; then
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    date_val="${date_raw// /}"
    new_date=$(extract_date "$date_val")

    if [[ "$new_date" == "NO_CHANGE" ]]; then
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [DRY-RUN] Would fix: $rel"
        echo "            date_created: '$date_val' → '$new_date'"
        FIXED=$((FIXED + 1))
    else
        set_result=$(obsidian property:set name="date_created" value="$new_date" type=date path="$rel" vault="$VAULT_NAME" 2>/dev/null)
        if echo "$set_result" | grep -qi '^Error'; then
            echo "  ERROR: $rel — $set_result" >&2
            ERRORS=$((ERRORS + 1))
        else
            echo "  FIXED: $rel  ($date_val → $new_date)"
            FIXED=$((FIXED + 1))
        fi
    fi
done < <(find "$VAULT" -name "*.md" "${FIND_EXCL[@]}" -print0)

echo ""
echo "Result: $FIXED fixed, $SKIPPED skipped, $ERRORS errors"
