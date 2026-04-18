#!/bin/bash
set -euo pipefail
# inspect-types.sh
# Checks: Frontmatter Guideline §1 — type field coverage and allowed values
#         Tag Guideline §4 — type/reference-tag alignment
#         Folder Guideline §3 — high-confidence type-folder mappings
#         Frontmatter Guideline §4 — music property allowed values

VAULT="${1:-./Ataraxia}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Type Coverage & Alignment Check ==="
echo "Vault: $VAULT"
echo ""

export VAULT SCRIPT_DIR

python3 << 'PYEOF'
import os, re, sys, json
from pathlib import Path
from collections import Counter

sys.path.insert(0, os.environ['SCRIPT_DIR'])
from frontmatter_parser import (
    iter_markdown_files, parse_frontmatter, parse_tags, parse_list_field, get_type_val,
    DEFAULT_EXCLUDE_DIRS,
)

for var in ['ALLOWED_TYPES_JSON', 'FOLDER_TYPE_RULES_JSON', 'TYPE_TAG_MAP_JSON']:
    if var not in os.environ:
        print(f"ERROR: {var} not set. Read guidelines and export env vars first (SKILL.md Step 1.1).", file=sys.stderr)
        sys.exit(1)

VAULT = Path(os.environ['VAULT'])
ALLOWED_TYPES = set(json.loads(os.environ['ALLOWED_TYPES_JSON']))

_fr = json.loads(os.environ['FOLDER_TYPE_RULES_JSON'])
PROJECT_AREA_FOLDERS = set(_fr.get('folders', []))
INDEX_TYPE = _fr.get('index_type', 'project')
DATE_PREFIX_TYPE = _fr.get('date_prefix_type', 'log')
DEFAULT_TYPE = _fr.get('default_type', 'note')
SUFFIX_OVERRIDES = _fr.get('suffix_overrides', {})
DATE_PREFIX_RE = re.compile(r'^\d{4}-\d{2}-\d{2}[\s_-]')
NUMERIC_PREFIX_RE = re.compile(r'^\d+\.\s*')

TYPE_TAG_MAP = json.loads(os.environ['TYPE_TAG_MAP_JSON'])

def folder_semantic_name(part: str) -> str:
    return NUMERIC_PREFIX_RE.sub('', part).strip().lower()

def is_archive_folder(part: str) -> bool:
    return folder_semantic_name(part) in {'archive', 'archives'}

FOLDER_TYPE_MAP = {
    ('80. References', '07 Github'): 'tool',
    ('50. AI', '02 Terminologies'): 'terminology',
    ('70. Collections', '03 MoC'): 'moc',
    ('80. References', '01 Book'): 'book',
}

MUSIC_ALLOWED = {
    'Classic', 'Jazz', 'CCM', 'Pop', 'Rock', 'Hip Hop',
    'Blues', 'R&B', 'Funk', 'Country', 'Folk', 'Electronic', '국악',
}

MAX_SAMPLES = 10

type_counts = Counter()
invalid_types = []
no_type = 0
type_tag_mismatches = []
folder_type_violations = []
dashboard_violations = []
folder_map_violations = []
music_violations = []
structural_yaml_skipped = 0
structural_yaml_samples = []
total = 0

for fpath in iter_markdown_files(VAULT):
    try:
        text = fpath.read_text(errors='ignore')
    except Exception:
        continue

    parsed = parse_frontmatter(text)
    if parsed['missing_frontmatter']:
        continue

    rel = str(fpath.relative_to(VAULT))
    if parsed['issues']:
        structural_yaml_skipped += 1
        if len(structural_yaml_samples) < 5:
            structural_yaml_samples.append(f"{rel} ({', '.join(parsed['issues'])})")
        continue

    fm = parsed['frontmatter'] or ''
    total += 1
    parts = fpath.relative_to(VAULT).parts[:-1]
    fname = fpath.name

    t = get_type_val(fm) or ''

    if not t:
        no_type += 1
    else:
        type_counts[t] += 1
        if t not in ALLOWED_TYPES and len(invalid_types) < MAX_SAMPLES:
            invalid_types.append(f'{rel}: type={t}')

    # Type/tag alignment for reference types
    if t in TYPE_TAG_MAP:
        expected_tag = TYPE_TAG_MAP[t]
        tags = parse_tags(fm)
        if tags and expected_tag not in tags and len(type_tag_mismatches) < MAX_SAMPLES:
            type_tag_mismatches.append(f'{rel}: type={t}, expected tag={expected_tag}, actual={tags[:2]}')

    # Project/Area/Archive 3-rule type check
    matching_folder = None
    subfolder_name = None
    for i, part in enumerate(parts):
        if part in PROJECT_AREA_FOLDERS:
            remaining = parts[i+1:]
            if is_archive_folder(part) and len(remaining) >= 2:
                subfolder_name = remaining[1]
            elif len(remaining) >= 1:
                subfolder_name = remaining[0]
            matching_folder = part
            break

    if matching_folder and subfolder_name:
        basename = fname[:-3]
        suffix_matched = False
        for suffix, stype in SUFFIX_OVERRIDES.items():
            if fname.endswith(suffix):
                expected = stype
                suffix_matched = True
                break
        if not suffix_matched:
            if basename == subfolder_name:
                expected = INDEX_TYPE
            elif DATE_PREFIX_RE.match(basename):
                expected = DATE_PREFIX_TYPE
            else:
                expected = DEFAULT_TYPE
        if t and t != expected and len(folder_type_violations) < 30:
            folder_type_violations.append(f'  - {rel}: type={t}, expected={expected}')

    # Dashboard type check (10. Time/06 Dashboard/)
    if len(parts) >= 2 and parts[0] == '10. Time' and parts[1] == '06 Dashboard':
        if t != 'plan' and len(dashboard_violations) < MAX_SAMPLES:
            dashboard_violations.append(f'  - {rel}: type={t or "(none)"}, expected=plan')

    # High-confidence folder-type mappings
    for folder_parts, expected_type in FOLDER_TYPE_MAP.items():
        depth = len(folder_parts)
        if parts[:depth] == folder_parts:
            if t and t != expected_type and len(folder_map_violations) < 20:
                folder_map_violations.append(f'  - {rel}: type={t}, expected={expected_type}')
            break

    # Music property allowed values
    music_vals = parse_list_field(fm, 'music')
    for mv in music_vals:
        if mv and mv not in MUSIC_ALLOWED and len(music_violations) < MAX_SAMPLES:
            music_violations.append(f'  - {rel}: music={mv}')

print(f"Total notes with frontmatter: {total}")
print(f"Notes without type: {no_type}")
print(f"Notes with type: {total - no_type} ({(total-no_type)/max(total,1)*100:.1f}% coverage)")
print()
print("--- Type Distribution ---")
for t, count in type_counts.most_common():
    marker = "  " if t in ALLOWED_TYPES else "! "
    print(f"  {marker}{t}: {count}")

sections = [
    (invalid_types, f"Invalid Type Values: {sum(1 for t in type_counts if t not in ALLOWED_TYPES)} distinct"),
    (type_tag_mismatches, f"Type/Tag Mismatches (reference types): {len(type_tag_mismatches)}"),
    (folder_type_violations, f"Project/Area/Archive Type Correctness: {len(folder_type_violations)} violations"),
    (dashboard_violations, f"06 Dashboard → plan: {len(dashboard_violations)} violations"),
    (folder_map_violations, f"Folder-Type Mapping Violations: {len(folder_map_violations)}"),
    (music_violations, f"Music Property Invalid Values: {len(music_violations)}"),
]
for items, label in sections:
    print(f"\n--- {label} ---")
    for s in items:
        print(f"  - {s}" if not s.startswith('  -') else s)

print(f"\n--- Skipped Structural YAML Files: {structural_yaml_skipped} ---")
for s in structural_yaml_samples: print(f"  - {s}")

print("\nDone.")
PYEOF
