---
name: obsidian-clipper-template-creator
description: Create importable JSON templates for Obsidian Web Clipper. Use when creating a new clipping template, understanding available variables, or formatting clipped content.
---

# Obsidian Web Clipper Template Creator

## Overview

Create importable JSON templates for the Obsidian Web Clipper. The workflow emphasizes selector verification and vault-aligned frontmatter so imported clips match the existing system instead of becoming one-off templates.

## When to Use

- User wants a new Web Clipper template for a specific site (YouTube, GitHub, etc.)
- User wants a new Web Clipper template for a content type (Recipe, Article, etc.)
- User needs to understand Clipper variables, filters, or template logic

## Workflow

1. **Identify User Intent:** specific site (YouTube), specific type (Recipe), or general clipping?
2. **Check Existing Bases:** Read `Bases/*.base` to find a matching category. Use properties defined in the Base to structure template properties. See [references/bases-workflow.md](bases-workflow.md).
3. **Check Frontmatter Guideline:** Read `90. Settings/01 Guideline/01. Frontmatter Guideline.md` to ensure properties match vault conventions (Core fields, type map, naming).
4. **Fetch & Analyze Reference URL:** Validate variables against a real page.
    - Ask the user for a sample URL (if not provided).
    - **(REQUIRED)** Use **WebFetch** to retrieve page content. See [references/analysis-workflow.md](analysis-workflow.md).
    - Analyze HTML for Schema.org JSON, Meta tags, and CSS selectors.
    - **(REQUIRED)** Verify each selector against fetched content. Do not guess selectors.
5. **Draft the JSON:** Create a valid JSON object following the schema. See [references/json-schema.md](json-schema.md).
6. **Consider template logic:** Conditionals for optional blocks, loops for list data, variable assignment to avoid repeating expressions, fallbacks for missing variables. See [references/logic.md](logic.md).
7. **Verify Variables:** Ensure chosen variables (Preset, Schema, Selector) exist in the analysis.
    - **(REQUIRED)** If a selector cannot be verified, state explicitly and ask for another URL.
    - See [references/variables.md](variables.md).

## Filter Pitfalls

- **`{{content}}` is already markdown.** Do NOT apply `|markdown` to it — `{{content|markdown}}` double-converts and breaks formatting (tables, code blocks, nested lists). Use `{{content}}` alone for article body content.
- **`|markdown` is for HTML sources only.** Use it with `{{contentHtml|markdown}}`, `{{selectorHtml:...|markdown}}`, or `{{fullHtml|markdown}}` — variables that return raw HTML.
- **`selectorHtml` returns HTML** and typically needs `|markdown`. `selector` returns text and does not.

## Selector Verification Rules

- **Always verify selectors** against live page content before responding.
- **Never guess selectors.** If the DOM cannot be accessed or the element is missing, ask for another URL or a screenshot.
- **Prefer stable selectors** (data attributes, semantic roles, unique IDs) over fragile class chains.
- **Document the target element** in your reasoning (e.g., "About sidebar paragraph") to reduce mismatch.

## Output Format

**ALWAYS** output the final result as a JSON code block the user can copy and import.

```json
{
  "schemaVersion": "0.1.0",
  "name": "My Template",
  ...
}
```

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll use a selector that looks right" | Selectors must be verified against fetched content. Guessed selectors break silently. |
| "Schema.org data is always available" | Many sites (e.g., GitHub) have no JSON-LD. Check first, fall back to preset/meta/selector. |
| "I don't need to check the Frontmatter Guideline" | Properties must match vault conventions. `source` vs `source_url`, required Core fields, type map. |
| "The filter chain will work" | Some filters conflict with template syntax (e.g., `split:":"`). Verify against real values. |

## Red Flags

These signs usually mean the template was assembled from assumptions instead of verified page data.

- Returning a template without verifying selectors against a live page
- Inventing frontmatter properties instead of checking the vault guideline or matching Base
- Responding with prose only instead of a copy-pastable JSON code block
- Reusing a selector from memory when the target page structure was not inspected

## Verification

After completing the template:
- [ ] JSON is valid and parseable
- [ ] All selectors verified against fetched page content
- [ ] Properties match Frontmatter Guideline conventions
- [ ] `noteNameFormat` produces a clean filename (test mentally against the real title)
- [ ] `triggers` array is appropriate for the target site
- [ ] `path` matches the vault folder structure

## Resources

- [references/variables.md](variables.md) - Available data variables
- [references/filters.md](filters.md) - Formatting filters
- [references/json-schema.md](json-schema.md) - JSON structure documentation
- [references/logic.md](logic.md) - Template logic
- [references/bases-workflow.md](bases-workflow.md) - How to map Bases to Templates
- [references/analysis-workflow.md](analysis-workflow.md) - How to validate page data

### Official Documentation

- [Variables](https://help.obsidian.md/web-clipper/variables)
- [Filters](https://help.obsidian.md/web-clipper/filters)
- [Logic](https://help.obsidian.md/web-clipper/logic)
- [Templates](https://help.obsidian.md/web-clipper/templates)

## Examples

See [assets/](assets/) for JSON examples.
