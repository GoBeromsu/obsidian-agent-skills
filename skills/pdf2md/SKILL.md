---
name: pdf2md
description: Convert PDF files to Markdown using Upstage Document Parse API. Use when the user says "PDF to markdown", "pdf2md", "PDF 변환", or wants to extract text and figures from a PDF into structured markdown.
---

# pdf2md

## Overview

Convert PDF to structured Markdown via the Upstage Document Parse API. Automatically selects sync (≤100 pages) or async (>100 pages) mode. Extracts figures as PNG, builds heading structure, and verifies output integrity.

## Prerequisites

- Python 3 with `requests`
- `UPSTAGE_API_KEY` environment variable
  - Get your key: https://console.upstage.ai/api-keys?api=chat
  - See `assets/.env.example`

## Process

### Phase 1 — Convert

```bash
# Dry run (estimate, no API call)
python3 scripts/pdf2md.py input.pdf -o /tmp/pdf2md_output

# Execute
python3 scripts/pdf2md.py input.pdf -o /tmp/pdf2md_output --confirm
```

Options:
- `--mode auto|standard|enhanced` (default: auto)
- `--model <name>` (default: document-parse-251217)
- `--toc toc.json` — fix heading hierarchy using known TOC structure

Output:
```
output-dir/
├── merged.md       # Full document
├── headings.json   # Heading structure
├── manifest.json   # Metadata + verification result
└── assets/         # Extracted figures (PNG)
```

### Phase 2 — Split (optional)

Split merged output into separate files by heading:

```bash
# By pattern
python3 scripts/pdf2md.py --split-from /tmp/pdf2md_output --split-pattern "Part" -o /tmp/split

# Every h1
python3 scripts/pdf2md.py --split-from /tmp/pdf2md_output --split-on-h1 -o /tmp/split
```

### Fix Headings (post-hoc)

```bash
python3 scripts/pdf2md.py --fix-headings /tmp/pdf2md_output --toc toc.json
```

TOC format:
```json
{
  "parts": {"Part 1: Title": 1},
  "chapters": {"Chapter Title": 2},
  "sections": {"Section Title": 3}
}
```

### Phase 3 — Vault Ingestion (optional)

For book PDFs, split output by chapter and create vault notes:

```bash
obsidian create vault="Ataraxia" path="80. References/01 Book/<title>/<chapter>.md" content="..."
```

- Books go to `80. References/01 Book/<title>/`
- Non-book PDFs go to the appropriate `80. References/` subfolder
- Each split chapter becomes its own note with normalized headings and frontmatter

## Verification

The script runs automatic checks after conversion:
- Heading hierarchy validity
- Image link integrity (`![[file]]` → existing PNG)
- Text completeness ratio (≥90%)
- Figure extraction count

Check `manifest.json → verification.passed` for pass/fail.

## Red Flags

- Running without `--confirm` and expecting output
- Missing `UPSTAGE_API_KEY`
- Ignoring verification warnings in manifest.json
