#!/bin/bash
# inspect-overview.sh
# Vault-wide stats using obsidian CLI and bash counts.
# Checks: overall note counts, orphans, unresolved links, property usage.
#
# Usage: bash .omc/vault-health/inspect-overview.sh
# Output: stdout (human-readable)

VAULT="${1:-./Ataraxia}"
VAULT_NAME="$(basename "$VAULT")"
EXCLUDE_PATTERN=".obsidian|.trash|.git|.omc|.claude|_archive|02 Templates"

echo "=== Vault Overview ==="
echo "Vault: $VAULT"
echo ""

# Total note count
TOTAL=$(find "$VAULT" -name "*.md" | grep -v -E "$EXCLUDE_PATTERN" | wc -l | tr -d ' ')
echo "Total .md files: $TOTAL"
echo ""

# obsidian CLI stats (requires running Obsidian instance)
echo "--- obsidian CLI Stats ---"
if command -v obsidian &>/dev/null; then
    echo "Properties overview:"
    obsidian properties counts format=json vault="$VAULT_NAME" 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
for item in sorted(data, key=lambda x: -x.get('count',0))[:20]:
    print(f\"  {item.get('name','?')}: {item.get('count','?')}\")
" 2>/dev/null || echo "  (obsidian CLI not available or vault not open)"

    echo ""
    echo "Tag counts (top 20):"
    obsidian tags counts format=json vault="$VAULT_NAME" 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
for item in sorted(data, key=lambda x: -x.get('count',0))[:20]:
    print(f\"  {item.get('tag','?')}: {item.get('count','?')}\")
" 2>/dev/null || echo "  (obsidian CLI not available)"

    echo ""
    echo "Orphaned files:"
    obsidian orphans total vault="$VAULT_NAME" 2>/dev/null || echo "  (obsidian CLI not available)"

    echo ""
    echo "Unresolved links:"
    obsidian unresolved verbose format=json vault="$VAULT_NAME" 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(f'  Total unresolved: {len(data)}')
for item in data[:5]:
    print(f\"  - {item.get('file','?')} -> {item.get('link','?')}\")
" 2>/dev/null || echo "  (obsidian CLI not available)"
else
    echo "  obsidian CLI not found. Install with: npm install -g @obsidian-cli/cli"
fi

echo ""
echo "--- File Count by Top-Level Folder ---"
for dir in "$VAULT"/*/; do
    dirname=$(basename "$dir")
    echo "$EXCLUDE_PATTERN" | grep -q "$dirname" && continue
    count=$(find "$dir" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    printf "  %-40s %s\n" "$dirname" "$count"
done

echo ""
echo "Done."
