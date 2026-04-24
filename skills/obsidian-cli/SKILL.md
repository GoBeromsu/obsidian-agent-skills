---
name: obsidian-cli
description: Interact with Obsidian vaults using the Obsidian CLI to read, create, search, and manage notes, tasks, properties, templates, bookmarks, history, sync, workspaces, and more. Also supports plugin and theme development with commands to reload plugins, run JavaScript via eval, capture errors, take screenshots, and inspect the DOM. Use when the user asks to interact with their Obsidian vault, manage notes, search vault content, perform vault operations from the command line, query Obsidian Bases, manage bookmarks or workspaces, inspect file history or sync versions, or develop and debug Obsidian plugins and themes.
---

# Obsidian CLI

## Overview

Use the `obsidian` CLI to interact with a running Obsidian instance for vault note operations, metadata edits, and plugin/runtime debugging. Requires Obsidian to be open.

## Command reference

Run `obsidian help` to see all available commands (90+). Run `obsidian help <command>` for detailed help on a specific command. Full docs: https://help.obsidian.md/cli

## Syntax

**Parameters** take a value with `=`. Quote values with spaces:

```bash
obsidian create name="My Note" content="Hello world"
```

**Flags** are boolean switches with no value:

```bash
obsidian create name="My Note" overwrite open
```

For multiline content use `\n` for newline and `\t` for tab.

## File targeting

Many commands accept `file` or `path` to target a file. Without either, the active file is used.

- `file=<name>` — resolves like a wikilink (name only, no path or extension needed)
- `path=<path>` — exact path from vault root, e.g. `folder/note.md`

## Vault targeting

Commands target the most recently focused vault by default. Use `vault=<name>` as the first parameter to target a specific vault:

```bash
obsidian vault=Ataraxia search query="test"
```

## When to Use

- User asks to read, create, append, prepend, rename, move, or delete vault notes
- User wants to search vault content or list files/tags/tasks
- User needs to update frontmatter properties
- User references a note by name or asks about backlinks/outgoing links
- User wants to manage bookmarks, workspaces, templates, or file history
- User needs to query Obsidian Bases (database views)
- Renaming or moving a vault file — **always prefer `obsidian rename` / `obsidian move` over Write+Bash rm**
- Plugin or theme development — reload, inspect, screenshot, eval

**NOT for:**
- Reading files outside the vault (use Read tool)
- Batch file operations on non-markdown assets (use Bash)

## Process

Use this loop to keep vault operations precise and reversible.

1. Target the correct vault and note first with `vault=`, `file=`, or `path=`.
2. Prefer the dedicated `obsidian` command (`rename`, `move`, `property:set`, etc.) over shell-side file edits.
3. Verify the result with a follow-up `obsidian` read/query command before concluding.

## Common patterns

```bash
# Read / create / edit
obsidian read file="My Note"
obsidian create name="New Note" content="# Hello" template="Template"
obsidian append file="My Note" content="New line"
obsidian prepend file="My Note" content="Top line"

# Rename in place (same folder, new name)
obsidian rename file="Old Name" name="New Name"

# Move to a different folder (can also rename simultaneously)
obsidian move file="My Note" to="20. Connect/My Note.md"

# Delete (sends to trash by default)
obsidian delete file="My Note"

# Search (see known limitations — may return empty)
obsidian search query="search term" limit=10
obsidian search:open query="search term"

# Links & graph analysis
obsidian backlinks file="My Note"
obsidian orphans total
obsidian unresolved counts

# Properties & tasks
obsidian property:set name="status" value="done" file="My Note"
obsidian property:read name="tags" file="My Note"
obsidian tasks todo verbose
obsidian tags sort=count counts

# Templates
obsidian template:insert name="Daily Template"
obsidian templater:create-from-template template="Templates/Zettel.md" file="10. Zettel/New.md"

# Bookmarks & workspaces
obsidian bookmark file="Important Note" title="Pinned"
obsidian workspace:load name="Writing"

# History & sync
obsidian history:read file="My Note" version=1
obsidian sync:status

# Base (database) queries
obsidian base:query file="Projects" view="Active" format=md

# Developer / eval (use IIFE for multi-statement: code="(()=>{...return val;})()")
obsidian eval code="app.vault.getFiles().length"
obsidian eval code="(()=>{const f=app.vault.getMarkdownFiles();return f.filter(x=>x.path.startsWith('15.')).length;})()"
obsidian dev:errors
obsidian dev:screenshot path=screenshot.png
```

Use `total` on list commands to get a count. Use `format=json|tsv|csv` on many commands for structured output.

## Reference files

Detailed documentation for all commands, organized by category:

| Reference | Commands |
|-----------|----------|
| `references/note-crud.md` | read, create, append, prepend, delete, rename, move, open, file, files |
| `references/search-links.md` | search, search:context, search:open, backlinks, links, orphans, deadends, unresolved, aliases |
| `references/properties-tags-tasks.md` | properties, property:read/set/remove, tags, tag, tasks, task |
| `references/vault-folders.md` | vault, vaults, folder, folders, reload, restart, version, wordcount, recents |
| `references/history-sync.md` | history, history:list/open/read/restore, sync, sync:*, diff |
| `references/templates.md` | templates, template:insert/read, templater:create-from-template |
| `references/base-database.md` | bases, base:create/query/views |
| `references/bookmarks.md` | bookmark, bookmarks |
| `references/workspace-ui.md` | workspace, workspaces, workspace:*, tabs, tab:open, outline, homepage, random, web |
| `references/plugins-themes-snippets.md` | plugin, plugins, plugin:*, theme, themes, theme:*, snippet:*, snippets |
| `references/commands-hotkeys.md` | command, commands, hotkey, hotkeys |
| `references/developer.md` | eval, dev:cdp/console/css/debug/dom/errors/mobile/screenshot, devtools |
| `references/known-limitations.md` | Search empty results, batch freeze, undocumented flags |
| `references/batch-operations.md` | Round-trip rename, health check pattern |
| `references/safe-update-pattern.md` | Safe rename with backlink sync — `obsidian rename` vs `bash mv` round-trip recovery |

Read the relevant reference file when you need detailed parameter info, examples, or tips for a specific command category.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll use Write + Bash rm to rename — it's simpler" | `obsidian rename` preserves backlinks and sync history. Write+rm breaks wikilinks across the vault. |
| "I'll use Read tool to read the note" | `obsidian read` returns resolved content including transclusions. Use it for vault notes. |
| "I need the exact path so I'll use `path=`" | `file=` resolves like a wikilink — name only works fine and is less fragile when notes move. |
| "I'll search with grep/qmd instead of obsidian search" | `obsidian search` is currently broken (returns empty). Use `qmd` or `search:open` as workarounds. This rationalization is actually correct for now. |
| "I'll use `return` or a bare expression in `eval`" | Top-level `return` throws `Illegal return statement`; bare trailing expressions produce no output. Wrap multi-statement code in an IIFE: `code="(()=>{...return val;})()"`. |

## Red Flags

- Using `Write` + `Bash rm` to rename vault notes instead of `obsidian rename`
- Using `Bash mv` to move vault files instead of `obsidian move`
- Hardcoding full paths with `path=` when `file=` (name-based) would work
- Not using `obsidian create` with `template=` when a template exists for the note type

## Verification

After vault file operations:
- [ ] `obsidian read file="<new-name>"` returns content without error
- [ ] Old filename no longer resolves (`obsidian file file="<old-name>"` returns not found)
- [ ] Backlinks still resolve (`obsidian backlinks file="<new-name>"`)

## Known Limitations (summary)

- **`search` / `search:context` returns empty results** — use `search:open` or `qmd` instead
- **Batch operations freeze after ~400 ops** — health check every 40 operations
- **Requires Obsidian.app to be running**

See `references/known-limitations.md` for details and workarounds.
