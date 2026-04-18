#!/bin/bash
set -euo pipefail
# inspect-frontmatter.sh
# Checks: Core Guideline §1.1 — required frontmatter fields, types, status
#         Core Guideline §1.4 — status required for specific types
#         Folder Guideline §3 — 50.AI/ created_by required

VAULT="${1:-./Ataraxia}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "=== inspect-frontmatter.sh ==="
echo "Vault: $VAULT"
echo ""

export VAULT SCRIPT_DIR

python3 << 'PYEOF'
import os, re, sys, json
from pathlib import Path

sys.path.insert(0, os.environ['SCRIPT_DIR'])
from frontmatter_parser import (
    iter_markdown_files, parse_frontmatter, get_type_val,
    DEFAULT_EXCLUDE_DIRS,
)

for var in ['REQUIRED_FIELDS_JSON', 'ALLOWED_TYPES_JSON', 'ALLOWED_STATUS_JSON']:
    if var not in os.environ:
        print(f"ERROR: {var} not set. Read guidelines and export env vars first (SKILL.md Step 1.1).", file=sys.stderr)
        sys.exit(1)

VAULT = Path(os.environ['VAULT'])
REQUIRED_FIELDS = json.loads(os.environ['REQUIRED_FIELDS_JSON'])
ALLOWED_TYPES = set(json.loads(os.environ['ALLOWED_TYPES_JSON']))
ALLOWED_STATUS = set(json.loads(os.environ['ALLOWED_STATUS_JSON']))
STATUS_REQUIRED_TYPES = set(json.loads(os.environ.get(
    'STATUS_REQUIRED_TYPES_JSON', '["project","book","paper","guide","draft","review"]')))

AI_PATH_PREFIX = '50. AI'
MAX_SAMPLES = 5

missing_counts = {f: 0 for f in REQUIRED_FIELDS}
missing_samples = {f: [] for f in REQUIRED_FIELDS}
invalid_type_count = 0
invalid_type_samples = []
invalid_status_count = 0
invalid_status_samples = []
missing_status_for_type_count = 0
missing_status_for_type_samples = []
ai_missing_created_by_count = 0
ai_missing_created_by_samples = []
structural_yaml_skipped = 0
structural_yaml_samples = []
total = 0

for fpath in iter_markdown_files(VAULT):
    total += 1
    try:
        text = fpath.read_text(errors='ignore')
    except (OSError, UnicodeDecodeError):
        continue

    rel = str(fpath.relative_to(VAULT))
    parsed = parse_frontmatter(text)
    if parsed['missing_frontmatter']:
        for field in REQUIRED_FIELDS:
            missing_counts[field] += 1
            if len(missing_samples[field]) < MAX_SAMPLES:
                missing_samples[field].append(rel)
        continue

    if parsed['issues']:
        structural_yaml_skipped += 1
        if len(structural_yaml_samples) < MAX_SAMPLES:
            structural_yaml_samples.append(f"{rel} ({', '.join(parsed['issues'])})")
        continue

    fm = parsed['frontmatter'] or ''
    keys = set(re.findall(r'^([a-zA-Z_][a-zA-Z0-9_\-]*)\s*:', fm, re.MULTILINE))

    for field in REQUIRED_FIELDS:
        if field not in keys:
            missing_counts[field] += 1
            if len(missing_samples[field]) < MAX_SAMPLES:
                missing_samples[field].append(rel)

    type_val = get_type_val(fm)
    if type_val is not None and type_val not in ALLOWED_TYPES:
        invalid_type_count += 1
        if len(invalid_type_samples) < MAX_SAMPLES:
            invalid_type_samples.append(f'{rel} ({type_val})')

    status_match = re.search(r'^status:[ \t]*(.+)', fm, re.MULTILINE)
    if status_match:
        status_val = status_match.group(1).strip().strip('"\'').lower()
        if status_val not in ALLOWED_STATUS:
            invalid_status_count += 1
            if len(invalid_status_samples) < MAX_SAMPLES:
                invalid_status_samples.append(f'{rel} ({status_val})')

    if type_val in STATUS_REQUIRED_TYPES and 'status' not in keys:
        missing_status_for_type_count += 1
        if len(missing_status_for_type_samples) < MAX_SAMPLES:
            missing_status_for_type_samples.append(f'{rel} (type={type_val})')

    parts = fpath.relative_to(VAULT).parts
    if parts and parts[0].startswith(AI_PATH_PREFIX):
        if len(parts) > 1 and parts[1].startswith('52. Terminologies'):
            pass  # mixed human/AI authorship — exempted from created_by requirement
        elif 'created_by' not in keys:
            ai_missing_created_by_count += 1
            if len(ai_missing_created_by_samples) < MAX_SAMPLES:
                ai_missing_created_by_samples.append(rel)

print(f'Total notes scanned: {total}\n')
print('--- Missing Required Fields ---')
for field in REQUIRED_FIELDS:
    pct = f'{missing_counts[field]/max(total,1)*100:.1f}%'
    s = ', '.join(missing_samples[field][:3]) if missing_samples[field] else ''
    print(f'  {field}: {missing_counts[field]} ({pct}){" — e.g. " + s if s else ""}')

print(f'\n--- Skipped Structural YAML Files: {structural_yaml_skipped} ---')
for s in structural_yaml_samples: print(f'    {s}')

print(f'\n--- Invalid Type Values: {invalid_type_count} ---')
for s in invalid_type_samples: print(f'    {s}')

print(f'\n--- Invalid Status Values: {invalid_status_count} ---')
for s in invalid_status_samples: print(f'    {s}')

print(f'\n--- Missing Status for Required Types: {missing_status_for_type_count} ---')
for s in missing_status_for_type_samples: print(f'    {s}')

print(f'\n--- 50. AI/ Missing created_by: {ai_missing_created_by_count} ---')
for s in ai_missing_created_by_samples: print(f'    {s}')
PYEOF
