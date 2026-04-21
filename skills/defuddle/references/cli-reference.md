# Defuddle CLI Reference

Version: 0.16.0
Binary: `/opt/homebrew/bin/defuddle`
Source: https://github.com/kepano/defuddle

## Commands

### `defuddle parse <source> [options]`

Parse HTML content from a file or URL.

| Option | Alias | Description |
|--------|-------|-------------|
| `--markdown` | `--md` | Convert content to markdown format |
| `--json` | `-j` | Output as JSON with metadata and content |
| `--property <name>` | `-p` | Extract a specific property (title, description, domain, etc.) |
| `--output <file>` | `-o` | Write output to file instead of stdout |
| `--lang <code>` | `-l` | Preferred language (BCP 47: en, ko, ja, etc.) |
| `--debug` | | Enable debug mode |

### Source types

- **URL**: `defuddle parse https://example.com/article`
- **Local file**: `defuddle parse ./page.html`

### Examples

```bash
# Clean markdown from a blog post
defuddle parse https://example.com/post --markdown

# JSON with metadata + content
defuddle parse https://example.com/post --json

# Just the title
defuddle parse https://example.com/post -p title

# Korean article, saved to file
defuddle parse https://example.com/ko/article --markdown -l ko -o article.md
```

## Fallback chain

1. `defuddle parse <url> --markdown` — first attempt for readable pages
2. `scrapling` — fallback for JS-heavy SPAs or empty defuddle results
3. `WebFetch` — last resort, or for API/JSON endpoints
