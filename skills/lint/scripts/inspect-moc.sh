#!/bin/bash
set -euo pipefail
# inspect-moc.sh
# Checks: MOC Guideline §3 — moc max 2 values, no Tier 0 direct links
#         MOC Guideline §3 — dual-moc per type (article/paper/terminology=2, project=0)
#         MOC Guideline §4.2 — MOC file required fields (type:moc, tags:[moc])
#         MOC Guideline §6 — MOC files must be in 03 MoC/, unnumbered detection
#         Core Guideline §3.2 — Permanent Notes must have moc

VAULT="${1:-./Ataraxia}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== MOC Assignment Health Check ==="
echo "Vault: $VAULT"
echo ""

export VAULT SCRIPT_DIR

python3 << 'PYEOF'
import os, re, sys
from pathlib import Path

sys.path.insert(0, os.environ['SCRIPT_DIR'])
from frontmatter_parser import (
    iter_markdown_files, parse_frontmatter, parse_list_field, get_type_val,
    DEFAULT_EXCLUDE_DIRS,
)

VAULT = Path(os.environ['VAULT'])
TIER0_RE = re.compile(r'📖\s*[1-9]00')
PERMANENT_PATH = str(VAULT / "40. Permanent Notes")
MOC_PATH = VAULT / "70. Collections" / "03 MoC"
MOC_NUMBERED_RE = re.compile(r'^\d{3}(\.\d{2})?[\s_]')

DUAL_MOC_TYPES = {'article', 'paper', 'terminology'}
ZERO_MOC_TYPES = {'project'}
MAX_SAMPLES = 5

stats = {
    'moc_over_2': 0, 'moc_tier0': 0,
    'no_moc_permanent': 0, 'permanent_total': 0,
    'moc_assigned': 0, 'total': 0,
    'dual_moc_wrong': 0, 'project_has_moc': 0,
    'moc_file_missing_type': 0, 'moc_file_missing_tag': 0,
    'moc_file_unnumbered': 0,
}
samples = {k: [] for k in [
    'moc_over_2', 'moc_tier0', 'no_moc_permanent',
    'dual_moc_wrong', 'project_has_moc',
    'moc_file_missing_type', 'moc_file_missing_tag',
    'moc_file_unnumbered',
]}
structural_yaml_skipped = 0
structural_yaml_samples = []

# Cache MOC file data during main walk to avoid double reads
moc_file_cache = {}

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
    stats['total'] += 1

    moc_vals = parse_list_field(fm, 'moc')
    type_val = get_type_val(fm)

    # Cache MOC file data for later self-validation
    if str(fpath).startswith(str(MOC_PATH)):
        moc_file_cache[fpath] = {
            'rel': rel, 'type_val': type_val,
            'tags': parse_list_field(fm, 'tags'),
        }

    if moc_vals:
        stats['moc_assigned'] += 1

    if len(moc_vals) > 2:
        record('moc_over_2', f'{rel} (count={len(moc_vals)})')

    for val in moc_vals:
        if TIER0_RE.search(val):
            record('moc_tier0', f'{rel}: {val[:50]}')

    if str(fpath).startswith(PERMANENT_PATH):
        stats['permanent_total'] += 1
        if not moc_vals:
            record('no_moc_permanent', rel)

    if type_val in DUAL_MOC_TYPES and len(moc_vals) != 2:
        record('dual_moc_wrong', f'{rel}: type={type_val}, moc count={len(moc_vals)}')

    if type_val in ZERO_MOC_TYPES and moc_vals:
        record('project_has_moc', f'{rel}: type={type_val}, moc={moc_vals[:2]}')

# === MOC File Self-Validation (from cache, no re-reads) ===
if MOC_PATH.exists():
    for fpath in MOC_PATH.iterdir():
        if not fpath.name.endswith('.md'):
            continue
        rel = str(fpath.relative_to(VAULT))

        if fpath in moc_file_cache:
            data = moc_file_cache[fpath]
            type_val = data['type_val']
            tags = data['tags']
        else:
            # File not in cache (e.g., had structural issues) — read it
            try:
                text = fpath.read_text(errors='ignore')
            except Exception:
                continue
            parsed = parse_frontmatter(text)
            if parsed['missing_frontmatter'] or parsed['issues']:
                continue
            fm = parsed['frontmatter'] or ''
            type_val = get_type_val(fm)
            tags = parse_list_field(fm, 'tags')

        if type_val != 'moc':
            record('moc_file_missing_type', f'{rel}: type={type_val or "(none)"}')

        if 'moc' not in tags:
            record('moc_file_missing_tag', f'{rel}: tags={tags[:3]}')

        if not MOC_NUMBERED_RE.match(fpath.name):
            record('moc_file_unnumbered', rel)

# === Output ===
print(f"Total notes: {stats['total']}")
print(f"MOC assigned: {stats['moc_assigned']} ({stats['moc_assigned']/max(stats['total'],1)*100:.1f}%)")
print()

sections = [
    ('moc_over_2', 'MOC > 2 values'),
    ('moc_tier0', 'Tier 0 direct links'),
    ('dual_moc_wrong', 'Dual-moc type mismatch (article/paper/terminology need 2)'),
    ('project_has_moc', 'Project type with moc (should be 0)'),
    ('moc_file_missing_type', 'MOC files missing type:moc'),
    ('moc_file_missing_tag', 'MOC files missing tags:[moc]'),
    ('moc_file_unnumbered', 'MOC files unnumbered'),
]
for key, label in sections:
    print(f"--- {label}: {stats[key]} ---")
    for s in samples[key]:
        print(f"  - {s}")
    print()

perm = stats['permanent_total']
no_moc = stats['no_moc_permanent']
cov = (perm - no_moc) / max(perm, 1) * 100
print(f"--- Permanent Notes ({perm} total) without MOC: {no_moc} ({cov:.1f}% coverage) ---")
for s in samples['no_moc_permanent']:
    print(f"  - {s}")

print()
print(f"--- Skipped Structural YAML Files: {structural_yaml_skipped} ---")
for s in structural_yaml_samples:
    print(f"  - {s}")

print()
print("Done.")
PYEOF
