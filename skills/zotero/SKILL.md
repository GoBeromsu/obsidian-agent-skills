---
name: zotero
description: >
  Full Zotero workflow: zt CLI for library search/browse/add/export, and vault CRUD for
  paper notes via ZotLit + GPP review generation. Covers both the CLI reference (search,
  fulltext, import, export, batch ops) and Obsidian vault pipeline (import → fix → sync → review).
  Trigger on: /zotero, 'zt', '논문 리뷰 만들어줘', 'zotero에서 가져와줘', '논문 찾아줘',
  '논문 노트 업데이트해줘', 'zotero 검색', 'PDF 추가해줘', 'DOI로 가져와', 'citation key', 'BibTeX'.
---

# Zotero Workflow

## Overview

Full Zotero workflow covering `zt` CLI (search, import, export, batch ops) and the Obsidian vault pipeline (import → normalize → sync → review). Paper notes live at `80. References/02 Paper/{citekey}.md`. BetterBibTeX must be enabled for correct citekey-based filenames.

## Vault Access

Use the `obsidian-cli` skill for all note creation, edit, search, and property mutation inside the Ataraxia vault. Do not shell out to raw `cat`/`sed` on vault paths. See the `obsidian-cli` SKILL.md for the command surface and required preconditions (Obsidian must be running).

## When to Use

- Use when the user wants to search Zotero, import a paper note, sync annotations, or create a review note
- Use when a Zotero-aware workflow is needed instead of generic PDF ingestion
- Use when the user mentions `zt`, citation key, BibTeX, or DOI
- Do not use when the source material is not managed in Zotero

## Process

### CREATE — Import Paper Note From Zotero

**Step 1A: Search vault first**

```bash
obsidian vault="Ataraxia" search query="{citekey}" path="80. References/02 Paper" format=json limit=5
```

If found, skip to UPDATE. Also check for legacy `🗞 ` prefix notes with Glob if search returns nothing.

**Step 1B: Import via ZotLit (if not found)**

```bash
obsidian vault="Ataraxia" command id=zotlit:refresh-zotero-data
obsidian vault="Ataraxia" command id=zotlit:import-note
```

`import-note` opens an interactive picker in Obsidian — user must select the paper manually.

**Hybrid alternative**: Use `zt search` + `zt get` + `obsidian create` to bypass the interactive picker:

```bash
zt search "paper title or keyword"
zt get <item-key> --children
zt bbt cite <item-key>
obsidian vault="Ataraxia" create path="80. References/02 Paper/<citekey>.md" content="..."
```

**Step 1C: Fix generated note (always required after import)**

ZotLit creates the file using the paper title as filename (no BBT = no citekey). Must fix:

1. Rename to citekey:
   ```bash
   obsidian vault="Ataraxia" rename path="80. References/02 Paper/{title-based}.md" name="{citekey}.md"
   ```
   Never use Bash `mv` — it breaks backlinks.

2. Supplement frontmatter (ZotLit does not populate these):
   ```yaml
   citekey: {citekey}
   date_created: {today}
   date_modified: {today}
   doi: {doi_or_url}
   tags: []
   type: paper
   up:
     - "[[02 Paper]]"
   venue: {conference/journal}
   ```

3. Fix body line: `[[.review]]` → `[[{citekey}.review]]`

4. Remove duplicate `---` lines — template bug produces extra horizontal rules after frontmatter and inside `## Annotation` section.

### READ — Sync Annotations

```bash
obsidian vault="Ataraxia" command id=zotlit:refresh-zotero-data
obsidian vault="Ataraxia" open path="80. References/02 Paper/{citekey}.md"
obsidian vault="Ataraxia" command id=zotlit:update-literature-note
```

Use `update-literature-note` (not `overwrite`) to preserve custom frontmatter fields.

`updateOverwrite` must be `false` in ZotLit's `data.json` — if `true`, ZotLit regenerates frontmatter from template and destroys manually-added fields (`citekey`, `doi`, `venue`, `date_created`, etc.).

### CREATE — Generate Review Note (GPP)

Check if review exists:
```bash
obsidian vault="Ataraxia" search query="{citekey}.review" limit=3
```

- Exists → Read and report. Stop unless user asks to regenerate.
- Not exists → Read PDF with Read tool, generate GPP review.

Review note at `80. References/02 Paper/{citekey}.review.md`:

```markdown
---
aliases: []
citekey: "{citekey}"
date_created: {today}
date_modified: {today}
tags: []
type: review
up:
  - "[[{citekey}]]"
---

## Pre-reading

### 배경
### 질문 혹은 가설
### 실험/접근 방법
### 결과, 관찰값
### 결론
### 전망과 한계점

## Critique

## Thinking
```

Terminology linking: first occurrence only, per section. Verify existing terminology notes before linking. Common: RAG → `[[Retriever-Augmented Generation (RAG)]]`, LLM → `[[Large Language Model (대규모 언어 모델)]]`.

### UPDATE — Re-sync or Regenerate

| Target | Command |
|---|---|
| Sync annotations from Zotero | `open` + `zotlit:update-literature-note` |
| Regenerate review | Delete review note, re-run GPP |
| Fix frontmatter fields | `obsidian vault="Ataraxia" property:set` |

## `zt` CLI Reference

`zt` (`@beomsukoh/zotero-cli`) — direct access to Zotero local library. Requires Zotero desktop running.

```bash
# Search & retrieve
zt search "attention mechanism"
zt search "deep learning" --limit 10 --sort dateAdded
zt search "neural" --tag AI --type journalArticle
zt bbt search "attention is all you need"
zt get <key> --children
zt fulltext <key>
zt items --top --limit 25
zt collections
zt bbt cite <key>

# Add files
zt import --doi "10.1038/s41586-021-03819-2"
zt import --arxiv "2301.01234" --collection <key>
zt import ./paper.pdf --doi "10.1234/example"
zt import --bibtex refs.bib
zt link paper.pdf --recognize

# Export
zt export --format bibtex
zt export --format csljson --collection <key>
zt download <key> --output ./paper.pdf

# Utility
zt setup         # Debug Bridge status
zt setup --fix   # Auto-configure
```

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I already know the paper is missing, so I can skip the vault search." | Duplicate literature notes are expensive and messy. |
| "The importer's default filename is good enough." | Citekey-based naming is required for predictable downstream workflows. |
| "Overwrite sync is faster." | Full overwrite destroys user-maintained frontmatter fields. |
| "I can rename with `mv`." | Always use `obsidian vault="Ataraxia" rename` to preserve backlinks. |

## Red Flags

- Import cleanup (Step 1C) skipped after ZotLit import
- `updateOverwrite=true` in `data.json` (destroys custom fields on sync)
- Annotation refresh overwrites custom frontmatter
- Review-note generation runs without checking for an existing review
- Bash `mv` used to rename instead of `obsidian rename`
- Note created at wrong path (not `80. References/02 Paper/`)

## Verification

After applying this skill, confirm:

- [ ] Vault search ran before import (no duplicates created)
- [ ] Imported note renamed to citekey filename
- [ ] Frontmatter supplemented with `citekey`, `doi`, `venue`, `type: paper`, `up: [[02 Paper]]`
- [ ] Duplicate `---` lines removed from note body
- [ ] Annotation sync used `update-literature-note` (not `overwrite`)
- [ ] Review note created at `80. References/02 Paper/{citekey}.review.md`
- [ ] `updateOverwrite=false` confirmed in ZotLit `data.json`
