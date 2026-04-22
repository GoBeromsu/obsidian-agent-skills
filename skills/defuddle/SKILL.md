---
name: defuddle
description: Extract clean markdown from web articles and documentation pages using Defuddle CLI. Use when fetching readable web content (blog posts, articles, docs) — produces cleaner output than WebFetch by stripping navigation, ads, and boilerplate. Not for API endpoints, JSON responses, or JS-heavy SPAs. Also handles local HTML files.
---

# Defuddle

## Overview

Defuddle (by kepano) extracts article content from web pages and returns clean markdown. It strips away navigation, ads, sidebars, and boilerplate — producing smaller, more focused content than a raw HTML fetch. It is the preferred web content extractor for readable pages in the vault workflow.

## Vault Access

Use the `obsidian-cli` skill for all note creation, edit, search, and property mutation inside the Ataraxia vault. Do not shell out to raw `cat`/`sed` on vault paths. See the `obsidian-cli` SKILL.md for the command surface and required preconditions (Obsidian must be running).

## When to Use

- Fetching article, blog, or documentation content for summarization or note-taking
- Extracting metadata (title, description, author, domain) from a web page
- Converting a local HTML file to clean markdown
- Any task where clean text matters more than raw HTML fidelity

**NOT for:**
- API endpoints or JSON responses — use `WebFetch`
- Sites requiring authentication or JavaScript rendering — use `scrapling`
- Cases where raw HTML structure is needed — use `WebFetch`

## Process

1. **Fetch as markdown** (default for most tasks):
   ```bash
   defuddle parse <url> --markdown
   ```

2. **Fetch as JSON** when you need metadata + content together:
   ```bash
   defuddle parse <url> --json
   ```

3. **Extract a single metadata field**:
   ```bash
   defuddle parse <url> -p title
   defuddle parse <url> -p description
   defuddle parse <url> -p domain
   ```

4. **Parse a local HTML file**:
   ```bash
   defuddle parse ./page.html --markdown
   ```

5. **Save output to file**:
   ```bash
   defuddle parse <url> --markdown -o output.md
   ```

6. **Specify preferred language** (BCP 47):
   ```bash
   defuddle parse <url> --markdown -l ko
   ```

7. **Check the result** — confirm the output is non-empty and materially cleaner than raw HTML. If the result is empty or poor quality (JS-heavy SPA), fall back to `scrapling`.

See `references/cli-reference.md` for full option details.

## Common Rationalizations

| Rationalization | Reality |
| --- | --- |
| "I'll use WebFetch and clean it manually later." | Defuddle handles the extraction and cleaning in one step — less token waste, cleaner result. |
| "The page is blank, so Defuddle is broken." | JS-heavy SPAs need a real browser. Fall back to `scrapling` instead. |
| "I don't need to check the output." | Extraction quality varies by site. A quick review prevents garbage downstream. |

## Red Flags

- `WebFetch` used for a standard readable page when `defuddle` would produce cleaner output
- Empty extraction passed downstream without attempting `scrapling` fallback
- Using `defuddle` for API endpoints or JSON responses
- Skipping `--markdown` flag (raw HTML is the default without it)

## Verification

- [ ] `defuddle parse <url> --markdown` was used as the first extraction attempt for readable pages
- [ ] Output mode matches the downstream task (markdown for content, JSON for metadata)
- [ ] Extracted content is non-empty
- [ ] `scrapling` fallback used when defuddle returns empty on JS-heavy sites
