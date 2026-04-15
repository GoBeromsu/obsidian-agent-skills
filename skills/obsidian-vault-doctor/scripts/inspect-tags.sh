#!/bin/bash
set -euo pipefail
# inspect-tags.sh
# Checks: Core Guideline §2 — tag format (lowercase, kebab-case, English only)
#         Tag Guideline §4 — no parent+child duplication
#         Tag Guideline §5 — minimum 1 tag per note
#         Tag Guideline §6 — legacy Zettel tags, Korean tags, CamelCase

VAULT="${1:-./Ataraxia}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Tag Health Check ==="
echo "Vault: $VAULT"
echo ""

export VAULT SCRIPT_DIR

python3 << 'PYEOF'
import os, re, sys
from pathlib import Path

sys.path.insert(0, os.environ['SCRIPT_DIR'])
from frontmatter_parser import (
    iter_markdown_files, parse_frontmatter, parse_tags,
    DEFAULT_EXCLUDE_DIRS,
)

VAULT = Path(os.environ['VAULT'])
KOREAN_RE = re.compile(r'[\uAC00-\uD7A3]')
UPPERCASE_RE = re.compile(r'[A-Z]')
NON_KEBAB_RE = re.compile(r'[_\s]')

stats = {
    'uppercase': 0, 'korean': 0, 'legacy_zettel': 0,
    'parent_child_dup': 0, 'empty_tags': 0, 'non_kebab': 0,
}
samples = {k: [] for k in stats}
MAX_SAMPLES = 5
structural_yaml_skipped = 0
structural_yaml_samples = []
total = 0

def record(cat, msg):
    stats[cat] += 1
    if len(samples[cat]) < MAX_SAMPLES:
        samples[cat].append(msg)

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
        if len(structural_yaml_samples) < MAX_SAMPLES:
            structural_yaml_samples.append(f"{rel} ({', '.join(parsed['issues'])})")
        continue

    fm = parsed['frontmatter'] or ''
    total += 1
    tags = parse_tags(fm)

    if not tags:
        record('empty_tags', rel)

    # Single pass over tags for all format checks
    has_upper = has_korean = has_zettel = has_non_kebab = False
    tag_set = set(tags)
    for tag in tags:
        if not has_upper and UPPERCASE_RE.search(tag):
            has_upper = True
            record('uppercase', f'{rel}: {tag}')
        if not has_korean and KOREAN_RE.search(tag):
            has_korean = True
            record('korean', f'{rel}: {tag}')
        if not has_zettel and tag.lower().startswith('zettel/'):
            has_zettel = True
            record('legacy_zettel', f'{rel}: {tag}')
        if not has_non_kebab and NON_KEBAB_RE.search(tag):
            has_non_kebab = True
            record('non_kebab', f'{rel}: {tag}')

    # Parent+child duplication
    for tag in tags:
        if '/' in tag:
            parent = tag.rsplit('/', 1)[0]
            if parent in tag_set:
                record('parent_child_dup', f'{rel}: {parent} + {tag}')
                break

labels = {
    'uppercase': 'Uppercase tags',
    'korean': 'Korean tags',
    'legacy_zettel': 'Legacy zettel/* tags',
    'parent_child_dup': 'Parent+child duplication',
    'empty_tags': 'Empty/missing tags',
    'non_kebab': 'Non-kebab-case (underscore/space)',
}

print(f"Total notes checked: {total}")
print()
print("--- Tag Violations ---")
for issue, count in stats.items():
    print(f"  {labels[issue]}: {count} files")
    for s in samples[issue]:
        print(f"    - {s}")

print()
print(f"Skipped structural YAML files: {structural_yaml_skipped}")
for s in structural_yaml_samples:
    print(f"  - {s}")

print()
print("Done.")
PYEOF
