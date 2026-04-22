---
name: book
description: Create or update book notes in the Obsidian vault with structured frontmatter, ToC skeleton, and body sections. Use when the user provides a book URL (yes24.com, aladin.co.kr), a book title, says "책 노트", "book note", "이 책 처리해줘", or wants to process a book from the Inbox. Also triggers on update requests like "하이라이트 정리", "목차 넣어줘", "프론트매터 정리".
---

# book

## Overview

Create or update book notes in `80. References/01 Book/`. Three source paths: URL-based (yes24.com), title-only (WebSearch fallback), or classic/historical text (Korean filename convention). Covers both creation and update workflows, including ToC skeleton injection and highlight-to-chapter mapping.

## Vault Access

Use the `obsidian-cli` skill for all note creation, edit, search, and property mutation inside the Ataraxia vault. Do not shell out to raw `cat`/`sed` on vault paths. See the `obsidian-cli` SKILL.md for the command surface and required preconditions (Obsidian must be running).

## When to Use

- Use when the user provides a yes24.com URL or any bookstore link
- Use when the user provides a book title and wants a vault note
- Use when an existing book note needs frontmatter migration or chapter reorganization
- Use when the user says "이 책 노트로 만들어줘", "book note 만들어줘", "업데이트하는데"
- Do not use for paper, article, or video notes

## Process

### Path A: URL provided

1. Run `uv run scripts/fetch_yes24.py <url>` (relative to this skill directory) to extract metadata JSON
2. The script returns: `title`, `subtitle`, `authors`, `cover_url`, `description`, `date_published`, `isbn13`, `categories`, `toc`, `introduce`, `in_book`, `pub_review`
3. If `toc` is empty (JS-rendered), try in order:
   a. `scrapling extract fetch "<url>" /tmp/yes24_toc.html --css-selector "#infoset_toc" --wait-selector "#infoset_toc textarea" --headless` — JS-rendered ToC 직접 추출
   b. If scrapling unavailable or fails, run `uv run scripts/fetch_aladin_toc.py <isbn13>` and OCR the returned image URLs with Claude vision
4. Compose the note and create via `obsidian vault="Ataraxia" create path="80. References/01 Book/<filename>.md" content="..."`

### Path B: Title only

1. WebSearch: `"<title>" site:yes24.com` to locate the product page
2. If found, follow Path A
3. If not found, WebSearch: `"<title>" site:aladin.co.kr` and extract metadata via WebFetch (the `fetch_yes24.py` script only works with yes24.com URLs)
4. If neither found, gather metadata from publisher sites, Wikipedia, book databases via WebSearch + WebFetch; populate at minimum `title`, `author`, `date_published`, `description`, and generate the 3줄 요약

### Path C: Classic/historical text

1. Use the most recognized Korean title as the filename (e.g., `기독교 강요.md`, `국부론.md`)
2. Include the original-language title in `aliases`
3. Separate original author and translator in the `author` field

### File Naming

Use the **original title language** as the filename; put the published Korean translation in `aliases`.

- Korean original: `우리가 빛의 속도로 갈 수 없다면.md`
- English original: `Antifragile.md` → `aliases: ["안티프래질"]`
- Japanese original: `君たちはどう生きるか.md`
- Classic exception: `기독교 강요.md` → `aliases: ["Institutio Christianae Religionis"]`

### Frontmatter

```yaml
---
aliases:
  - "출판된 번역 제목"
author:
  - "[[저자명]]"
cover_url: https://...
date_created: YYYY-MM-DD
date_modified: YYYY-MM-DD
date_published: YYYY-MM-DD
date_started: YYYY-MM-DD
description: ...
isbn: ...
source_url: <book URL>
status: todo
subtitle: ...
tags:
  - reading
  - reading/YYYY
  - <genre tag in English>
title: ...
type: book
---
```

### Body structure

```markdown
> [!summary]+ 3 줄 요약
> - (AI-generated Korean bullet 1)
> - (AI-generated Korean bullet 2)
> - (AI-generated Korean bullet 3)

## Linking
-
# 목차
(## for main sections, ### and #### for subsections, no blank lines between entries)

# 책소개
(prose from #infoset_introduce)

## 책 속으로
(prose from #infoset_inBook)

## 출판사 리뷰
(prose from #infoset_pubReivew; third-party quotes as blockquotes)
```

### Updating an Existing Note

Trigger: user says "update", "업데이트", or asks to organize highlights under chapters.

1. Read the existing note — collect all frontmatter, quotes, and personal notes
2. Get ToC via `uv run scripts/fetch_yes24.py <source_url>`; fall back to `uv run scripts/fetch_aladin_toc.py <isbn13>` + OCR
3. Migrate deprecated frontmatter fields:
   - `publish_date` → `date_published`, `start_read_date` → `date_started`
   - `my_rate`, `book_note`, `category`, `total_page` → remove
   - `author` strings → `"[[Author Name]]"` wikilink format
4. Classify content: personal notes (date-stamped `[[YYYY-MM-DD]]` bullets, first-person) vs book quotes (blockquotes)
5. Map each highlight to the most thematically relevant chapter heading
6. Deduplicate: keep the instance with more context; remove bare duplicates
7. If the current filename is a Korean translation of a foreign-language original, rename with `obsidian vault="Ataraxia" move` and move the Korean title into `aliases`

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "The title is close enough; I can skip metadata cleanup." | Inconsistent metadata makes notes hard to search and deduplicate. |
| "I'll create a second note instead of renaming the first one." | Duplicate book notes cause vault drift and broken wikilinks. |
| "A storefront summary is enough; I don't need the ToC." | A note with accumulated highlights but no chapter structure is as unfinished as a blank template. |
| "I can use `mv` to rename the file." | Always use `obsidian vault="Ataraxia" move` to preserve backlinks. |
| "The script failed, so I'll skip metadata and just create a stub." | Try at least 2 alternative sources (aladin script, publisher site, WebSearch) before falling back to manual metadata. |

## Red Flags

- The workflow creates duplicate notes instead of renaming or updating in place
- Filename and alias rules are mixed up (Korean title as filename for foreign-language original)
- Required frontmatter fields are missing after creation
- Filesystem `mv`/`cp` used instead of `obsidian move`
- ToC sourcing skipped when yes24 `toc` field is empty

## Verification

After completing the workflow, confirm:

- [ ] Metadata resolved from at least one authoritative source (yes24, aladin, publisher, or WebSearch)
- [ ] Filename follows original-language convention; Korean translation in `aliases`
- [ ] Frontmatter includes all required fields: `title`, `author` (wikilink format `[[Name]]`), `type: book`, `status`, `tags` (reading, reading/YYYY), `date_created`, `isbn`
- [ ] Body has: 3줄 요약 callout, `## Linking`, `# 목차`
- [ ] Existing highlight content preserved or mapped to chapters (update flow)
- [ ] Note created/updated at `80. References/01 Book/<filename>.md`
- [ ] No Inbox placeholder left behind after processing
