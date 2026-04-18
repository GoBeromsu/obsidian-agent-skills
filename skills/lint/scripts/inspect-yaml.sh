#!/bin/bash
set -euo pipefail
# inspect-yaml.sh
# Checks: Core Guideline §1.2 — YAML formatting rules
#         - Malformed opener, oversized delimiters, unquoted wikilinks
#         - Datetime in date fields, deprecated keys
#         - Wikilink usage restriction (01. Frontmatter Guideline Caveat)
#         - Empty wikilinks, boolean field validation

VAULT="${1:-./Ataraxia}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== YAML Structure Health Check ==="
echo "Vault: $VAULT"
echo ""

export VAULT SCRIPT_DIR

python3 << 'PYEOF'
import os, re, sys
from pathlib import Path

sys.path.insert(0, os.environ['SCRIPT_DIR'])
from frontmatter_parser import iter_markdown_files, parse_frontmatter, DEFAULT_EXCLUDE_DIRS

VAULT = Path(os.environ['VAULT'])

import json, os
DEPRECATED = set(json.loads(os.environ.get('DEPRECATED_KEYS_JSON', '[]')))
DATE_FIELDS = {'date_created', 'date_modified', 'date_published', 'date_started', 'date_finished'}
DATETIME_RE = re.compile(r'\d{4}-\d{2}-\d{2}T')

WIKILINK_ALLOWED_PROPS = {
    'up', 'moc', 'index', 'project', 'related', 'referenced', 'review',
    'author', 'source', 'created_by', 'modified_by',
    'church', 'speaker', 'participants', 'proposer',
    'week', 'month', 'year', 'quarter', 'roundup', 'meeting', 'book',
}

BOOLEAN_FIELDS = {
    'workout', 'published', 'dg-publish', 'archived', 'deleted',
    'fact_checked', 'mobile',
}

MAX_SAMPLES = 5
WIKILINK_RE = re.compile(r'\[\[.*?\]\]')
EMPTY_WIKILINK_RE = re.compile(r'\[\[\s*\]\]')

stats = {
    'malformed_opener': 0, 'oversized_delimiter': 0,
    'missing_closing_delimiter': 0, 'deprecated_key': 0,
    'datetime_in_date': 0, 'unquoted_wikilink': 0,
    'wikilink_forbidden': 0, 'empty_wikilink': 0,
    'boolean_invalid': 0,
}
samples = {k: [] for k in stats}
deprecated_counts = {k: 0 for k in DEPRECATED}

def record(cat, msg):
    stats[cat] += 1
    if len(samples[cat]) < MAX_SAMPLES:
        samples[cat].append(msg)

for fpath in iter_markdown_files(VAULT):
    try:
        text = fpath.read_text(errors='ignore')
    except Exception:
        continue

    rel = str(fpath.relative_to(VAULT))
    parsed = parse_frontmatter(text)

    if 'malformed_opener' in parsed['issues']:
        record('malformed_opener', rel)
    if any(i.startswith('oversized_') for i in parsed['issues']):
        record('oversized_delimiter', rel)
    if 'missing_closing_delimiter' in parsed['issues']:
        record('missing_closing_delimiter', rel)

    if parsed['missing_frontmatter'] or parsed['issues']:
        continue

    fm = parsed['frontmatter'] or ''
    current_prop = None

    for line in fm.split('\n'):
        prop_match = re.match(r'^([a-zA-Z_][a-zA-Z0-9_-]*)\s*:', line)
        if prop_match:
            current_prop = prop_match.group(1)

        # Deprecated keys — O(1) set lookup
        if current_prop in DEPRECATED and prop_match:
            deprecated_counts[current_prop] += 1
            record('deprecated_key', f'{rel}: {line.strip()}')

        # Datetime in date fields
        if current_prop in DATE_FIELDS and prop_match and DATETIME_RE.search(line):
            record('datetime_in_date', f'{rel}: {line.strip()[:60]}')

        # Unquoted wikilinks
        if '[[' in line and ']]' in line:
            if not re.search(r'["\'].*\[\[.*\]\].*["\']', line):
                stripped = line.strip()
                if not (stripped.startswith('- "[[') or stripped.startswith("- '[[")):
                    record('unquoted_wikilink', f'{rel}: {stripped[:70]}')

        # Empty wikilinks
        if EMPTY_WIKILINK_RE.search(line):
            record('empty_wikilink', f'{rel}: {line.strip()[:70]}')

        # Wikilink in forbidden property
        if WIKILINK_RE.search(line) and not EMPTY_WIKILINK_RE.search(line):
            check_prop = current_prop
            if check_prop and check_prop not in WIKILINK_ALLOWED_PROPS:
                if not re.search(r'!\[\[', line):
                    record('wikilink_forbidden',
                           f'{rel}: {check_prop}: {line.strip()[:60]}')

        # Boolean field validation
        if current_prop in BOOLEAN_FIELDS and prop_match:
            val = line.split(':', 1)[1].strip() if ':' in line else ''
            if val:
                if (val.startswith(('"', "'")) and val.strip('"\'').lower() in ('true', 'false')) \
                   or val in ('0', '1'):
                    record('boolean_invalid', f'{rel}: {current_prop}: {val}')

print(f"--- Malformed Openers: {stats['malformed_opener']} ---")
for s in samples['malformed_opener']: print(f"  - {s}")

print(f"\n--- Oversized Delimiters: {stats['oversized_delimiter']} ---")
for s in samples['oversized_delimiter']: print(f"  - {s}")

print(f"\n--- Missing Closing Delimiters: {stats['missing_closing_delimiter']} ---")
for s in samples['missing_closing_delimiter']: print(f"  - {s}")

print(f"\n--- Deprecated Keys: {stats['deprecated_key']} ---")
for key, count in deprecated_counts.items():
    if count: print(f"  {key}: {count} files")
for s in samples['deprecated_key']: print(f"    - {s}")

print(f"\n--- Datetime in Date Fields: {stats['datetime_in_date']} ---")
for s in samples['datetime_in_date']: print(f"  - {s}")

print(f"\n--- Unquoted Wikilinks: {stats['unquoted_wikilink']} ---")
for s in samples['unquoted_wikilink']: print(f"  - {s}")

print(f"\n--- Wikilink in Forbidden Property: {stats['wikilink_forbidden']} ---")
for s in samples['wikilink_forbidden']: print(f"  - {s}")

print(f"\n--- Empty Wikilinks: {stats['empty_wikilink']} ---")
for s in samples['empty_wikilink']: print(f"  - {s}")

print(f"\n--- Boolean Field Errors: {stats['boolean_invalid']} ---")
for s in samples['boolean_invalid']: print(f"  - {s}")

print("\nDone.")
PYEOF
