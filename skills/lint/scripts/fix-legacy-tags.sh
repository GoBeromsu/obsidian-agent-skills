#!/bin/bash
set -euo pipefail
# fix-legacy-tags.sh
# Guideline: 03. Tag Guideline §6 — Legacy zettel/* tags must be replaced
# Fixes: zettel/fleeting → fleeting, zettel/permanent → permanent, zettel/literature → literature

VAULT="${1:-./Ataraxia}"
VAULT_NAME="$(basename "$VAULT")"
DRY_RUN=false
for arg in "${@:2}"; do [[ "$arg" == "--dry-run" ]] && DRY_RUN=true; done

if ! pgrep -x "Obsidian" > /dev/null 2>&1; then
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "SKIP: Obsidian not running; dry-run skipped for fix-legacy-tags.sh"
        exit 0
    else
        echo "ERROR: Obsidian is not running. Please open Obsidian first." >&2
        exit 1
    fi
fi

echo "=== fix-legacy-tags.sh ==="
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

while IFS= read -r -d '' mdfile; do
    rel="${mdfile#"$VAULT/"}"

    tags_raw=$(obsidian property:read name="tags" path="$rel" vault="$VAULT_NAME" 2>/dev/null || true)
    if [[ -z "$tags_raw" ]] || echo "$tags_raw" | grep -qi '^Error'; then
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    # Check if any zettel/* tag exists
    if ! echo "$tags_raw" | grep -qi "zettel/"; then
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    result=$(python3 - "$tags_raw" <<'PYEOF'
import sys, re

raw = sys.argv[1].strip()
if '\n' in raw:
    tags = [t.strip().lstrip('- ').strip() for t in raw.split('\n') if t.strip()]
else:
    tags = [t.strip() for t in raw.split(',') if t.strip()]

mapping = {
    'zettel/fleeting': 'fleeting',
    'zettel/permanent': 'permanent',
    'zettel/literature': 'literature',
    'zettel/reference': 'reference',
}

changed = False
new_tags = []
for t in tags:
    lower = t.lower()
    if lower in mapping:
        new_tags.append(mapping[lower])
        changed = True
    elif lower.startswith('zettel/'):
        # Generic zettel/* → strip prefix
        new_tags.append(t[7:])
        changed = True
    else:
        new_tags.append(t)

if not changed:
    print("NO_CHANGE")
    sys.exit(0)

print(','.join(new_tags))
PYEOF
)

    if [[ "$result" == "NO_CHANGE" ]]; then
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [DRY-RUN] Would fix: $rel"
        echo "            tags → [$result]"
        FIXED=$((FIXED + 1))
    else
        set_result=$(obsidian property:set name="tags" value="[$result]" type=list path="$rel" vault="$VAULT_NAME" 2>/dev/null)
        if echo "$set_result" | grep -qi '^Error'; then
            echo "  ERROR: $rel — $set_result" >&2
            ERRORS=$((ERRORS + 1))
        else
            echo "  FIXED: $rel"
            FIXED=$((FIXED + 1))
        fi
    fi
done < <(find "$VAULT" -name "*.md" "${FIND_EXCL[@]}" -print0)

echo ""
echo "Result: $FIXED fixed, $SKIPPED skipped, $ERRORS errors"
