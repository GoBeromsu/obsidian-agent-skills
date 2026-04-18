#!/bin/bash
set -euo pipefail
# fix-yaml-delimiters.sh
# Guideline: 00. Core Guideline §1.2 — YAML frontmatter delimiters must be exactly ---
# Fixes:
#   - -----(4+ dashes) → --- when used as YAML opening/closing delimiter
#   - ---aliases: [] → ---\naliases: [] for malformed opening line repair
# Auto-fixable: Yes — mechanical delimiter / newline normalization only

VAULT="${1:-./Ataraxia}"
DRY_RUN=false
TARGET_PATH=""
for arg in "${@:2}"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    *) TARGET_PATH="$arg" ;;
  esac
done
export DRY_RUN TARGET_PATH
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export VAULT SCRIPT_DIR TARGET_PATH

echo "=== fix-yaml-delimiters.sh ==="
echo "Vault: $VAULT"
echo "Dry-run: $DRY_RUN"
if [[ -n "$TARGET_PATH" ]]; then
    echo "Target path: $TARGET_PATH"
fi
echo "Fixing YAML delimiter errors (----+ -> ---, ---<key>: -> ---\\n<key>:)"
echo ""

python3 - <<'PYEOF'
import os
import sys
from pathlib import Path

sys.path.insert(0, os.environ['SCRIPT_DIR'])
from frontmatter_parser import iter_markdown_files, repair_frontmatter_text

vault = os.environ.get('VAULT', './Ataraxia')
dry_run = os.environ.get('DRY_RUN', 'false').lower() == 'true'
target_path = os.environ.get('TARGET_PATH', '').strip()
vault_path = Path(vault)
exclude_dirs = {'.obsidian', '.trash', '.git', '.omc', '.claude', '_archive', '02 Templates'}
fixed = 0
errors = 0

if target_path:
    resolved = Path(target_path)
    if not resolved.is_absolute():
        resolved = vault_path / target_path
    if not resolved.exists():
        print(f"ERROR: target path not found: {resolved}", file=sys.stderr)
        sys.exit(1)
    paths = [resolved]
else:
    paths = iter_markdown_files(vault_path, exclude_dirs)

for path in paths:
    try:
        content = path.read_text(encoding='utf-8')
    except Exception:
        errors += 1
        continue

    new_content, changes = repair_frontmatter_text(content)
    if not changes:
        continue

    rel = str(path.relative_to(vault_path))
    if dry_run:
        print(f'  [DRY-RUN] Would fix: {rel}')
        print(f"            changes: {', '.join(changes)}")
        fixed += 1
        continue

    path.write_text(new_content, encoding='utf-8')
    fixed += 1
    print(f'  FIXED: {rel} ({", ".join(changes)})')

print(f'\nResult: {fixed} files fixed, {errors} errors')
PYEOF
