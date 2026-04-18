#!/bin/bash
set -euo pipefail
# fix-tag-parent-child.sh
# Guideline: 03. Tag Guideline §4 — Do not use parent+child tag together; use child only
# Fixes: removes parent tag when child tag is also present
#   e.g. [reference, reference/article] → [reference/article]
#   e.g. [faith, faith/bible] → [faith/bible]

VAULT="${1:-./Ataraxia}"
VAULT_NAME="$(basename "$VAULT")"
DRY_RUN=false
for arg in "${@:2}"; do [[ "$arg" == "--dry-run" ]] && DRY_RUN=true; done

if ! pgrep -x "Obsidian" > /dev/null 2>&1; then
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "SKIP: Obsidian not running; dry-run skipped for fix-tag-parent-child.sh"
        exit 0
    else
        echo "ERROR: Obsidian is not running. Please open Obsidian first." >&2
        exit 1
    fi
fi

echo "=== fix-tag-parent-child.sh ==="
echo "Vault: $VAULT"
echo "Dry-run: $DRY_RUN"
echo ""

EXCL_DIRS=(".obsidian" ".trash" ".git" ".omc" ".claude" "_archive" "02 Templates")
FIXED=0
SKIPPED=0
ERRORS=0

# Build find exclude args
FIND_EXCL=()
for d in "${EXCL_DIRS[@]}"; do
    FIND_EXCL+=(-not -path "*/$d/*")
done

while IFS= read -r -d '' mdfile; do
    # Read current tags via obsidian CLI (use path= for exact file)
    rel="${mdfile#"$VAULT/"}"
    name="${rel%.md}"

    tags_raw=$(obsidian property:read name="tags" path="$rel" vault="$VAULT_NAME" 2>/dev/null || true)
    if [[ -z "$tags_raw" ]] || echo "$tags_raw" | grep -qi '^Error'; then
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    # Use Python only for the string logic (no YAML touching)
    result=$(python3 - "$tags_raw" <<'PYEOF'
import sys, re

raw = sys.argv[1].strip()
# Parse comma or newline separated tags (obsidian CLI returns one per line or comma list)
if '\n' in raw:
    tags = [t.strip().lstrip('- ').strip() for t in raw.split('\n') if t.strip()]
else:
    tags = [t.strip() for t in raw.split(',') if t.strip()]

tag_set = set(tags)
to_remove = set()
for t in tags:
    if '/' in t:
        parent = t.rsplit('/', 1)[0]
        if parent in tag_set:
            to_remove.add(parent)

if not to_remove:
    print("NO_CHANGE")
    sys.exit(0)

new_tags = [t for t in tags if t not in to_remove]
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
