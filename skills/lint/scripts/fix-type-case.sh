#!/bin/bash
set -euo pipefail
# fix-type-case.sh
# Guideline: 00. Core Guideline §3 — type field must be lowercase
# Fixes: uppercase/mixed-case type values → lowercase
#   e.g. "CMDS" → "cmds", "Note" → "note", "MOC" → "moc"

VAULT="${1:-./Ataraxia}"
VAULT_NAME="$(basename "$VAULT")"
DRY_RUN=false
for arg in "${@:2}"; do [[ "$arg" == "--dry-run" ]] && DRY_RUN=true; done

if ! pgrep -x "Obsidian" > /dev/null 2>&1; then
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "SKIP: Obsidian not running; dry-run skipped for fix-type-case.sh"
        exit 0
    else
        echo "ERROR: Obsidian is not running. Please open Obsidian first." >&2
        exit 1
    fi
fi

echo "=== fix-type-case.sh ==="
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

    type_raw=$(obsidian property:read name="type" path="$rel" vault="$VAULT_NAME" 2>/dev/null || true)
    if [[ -z "$type_raw" ]] || echo "$type_raw" | grep -qi '^Error'; then
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    type_val="${type_raw// /}"  # trim whitespace
    type_lower=$(echo "$type_val" | tr '[:upper:]' '[:lower:]')

    if [[ "$type_val" == "$type_lower" ]]; then
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [DRY-RUN] Would fix: $rel"
        echo "            type: '$type_val' → '$type_lower'"
        FIXED=$((FIXED + 1))
    else
        set_result=$(obsidian property:set name="type" value="$type_lower" path="$rel" vault="$VAULT_NAME" 2>/dev/null)
        if echo "$set_result" | grep -qi '^Error'; then
            echo "  ERROR: $rel — $set_result" >&2
            ERRORS=$((ERRORS + 1))
        else
            echo "  FIXED: $rel  ($type_val → $type_lower)"
            FIXED=$((FIXED + 1))
        fi
    fi
done < <(find "$VAULT" -name "*.md" "${FIND_EXCL[@]}" -print0)

echo ""
echo "Result: $FIXED fixed, $SKIPPED skipped, $ERRORS errors"
