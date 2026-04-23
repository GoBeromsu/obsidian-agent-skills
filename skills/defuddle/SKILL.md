---
name: defuddle
description: Extract clean markdown from web articles and documentation pages using Defuddle CLI. Use when fetching readable web content (blog posts, articles, docs) — produces cleaner output than WebFetch by stripping navigation, ads, and boilerplate. Not for API endpoints, JSON responses, or JS-heavy SPAs. Also handles local HTML files.
---

# Defuddle

Defuddle extracts article content from web pages and returns clean markdown, stripping navigation, ads, sidebars, and boilerplate. Preferred over WebFetch for readable pages.

## When to Use

- Fetching article, blog, or documentation content
- Extracting metadata from a web page
- Converting a local HTML file to clean markdown

**Not for:** API endpoints, JSON responses, sites requiring authentication or JavaScript rendering (use `scrapling`), or cases where raw HTML structure is needed.

## Commands

```bash
# Markdown output (default for most tasks)
defuddle parse <url> --markdown

# JSON output — metadata + content together
defuddle parse <url> --json

# Extract a single metadata field
defuddle parse <url> -p title
defuddle parse <url> -p description
defuddle parse <url> -p domain

# Local HTML file
defuddle parse ./page.html --markdown

# Save to file
defuddle parse <url> --markdown -o output.md

# Preferred language (BCP 47)
defuddle parse <url> --markdown -l ko
```

If output is empty or poor quality (JS-heavy SPA), fall back to `scrapling`.

## URL Validation Posture

Pass URLs exactly as provided. Do not modify, normalize, or validate URLs before passing them to defuddle — let the CLI handle errors.

## Checklist

- [ ] Used `--markdown` for readable pages (raw HTML is the default without it)
- [ ] Output mode matches downstream task (markdown for content, JSON for metadata)
- [ ] Extracted content is non-empty; used `scrapling` fallback if empty

## Using defuddle for ingest-style metadata extraction

When ingesting a URL into the vault, use JSON mode to capture all metadata in one pass:

```bash
defuddle parse "URL" --json
```

The JSON output follows this canonical schema:

| Field | Source |
| --- | --- |
| `title` | `<title>` or `og:title` |
| `author` | byline or `author` meta |
| `description` | `meta[name=description]` or `og:description` |
| `domain` | hostname extracted from URL |
| `image` | `og:image` |
| `language` | `lang` attribute or `Content-Language` header |
| `published` | `article:published_time` or date byline |
| `content` | cleaned article body as markdown |

Use `-p <field>` to extract a single field (e.g., `defuddle parse "URL" -p title`).

After extraction, map these fields directly into the note's YAML frontmatter. If any field is missing in the JSON output, leave it blank rather than guessing.
