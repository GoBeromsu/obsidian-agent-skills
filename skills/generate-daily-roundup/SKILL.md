---
name: generate-daily-roundup
description: Use when you need to synthesize a day of source notes into a daily roundup, especially for date-scoped source collection, theme extraction, narrative synthesis, and final roundup note generation. Trigger keywords include `gdr`, "daily roundup", "generate daily roundup".
---

# generate-daily-roundup

## Overview

Generate a daily roundup by synthesizing the day’s vault activity into a thematic narrative. Sources are discovered across `15. Work/01 Project/`, `15. Work/02 Area/`, `80. References/`, and the daily note at `10. Time/01 Daily Notes/YYYY-MM-DD.md`. Output goes into a section of that daily note. Quality targets from `references/quality-standard.md`: 4+ sources, 8+ validated wikilinks, 2+ cross-source connections, 60+ output lines.

## Vault Access

Use the `obsidian-cli` skill for all note creation, edit, search, and property mutation inside the Ataraxia vault. Do not shell out to raw `cat`/`sed` on vault paths. See the `obsidian-cli` SKILL.md for the command surface and required preconditions (Obsidian must be running).

## When to Use
- Use when the user wants a daily synthesis across notes collected during a single day
- Use when multiple sources should be turned into one narrative roundup or recap note
- Use when date-scoped source gathering and synthesis are more important than raw listing
- Do not use for weekly or long-range synthesis — use `generate-weekly-roundup` for that

## Process
1. **Define the day scope**
	- Resolve the target date (default: today).
	- Read the daily note: `obsidian vault=”Ataraxia” read path=”10. Time/01 Daily Notes/YYYY-MM-DD.md”`

2. **Collect candidate notes**
	- Search across source folders:
	  - `obsidian vault=”Ataraxia” search query=”date:YYYY-MM-DD” format=json`
	  - Sweep folders: `15. Work/01 Project/`, `15. Work/02 Area/`, `80. References/`
	- Merge `obsidian search` results with `obsidian files` folder sweeps (search alone misses recently created files).
	- Filter: require 200+ chars of body content; drop test/empty files.
	- Verify each source exists before including: `obsidian vault=”Ataraxia” read path=”SOURCE_PATH.md”` — never write a section for a file that fails to read.

3. **Extract themes and narrative threads**
	- Identify repeated ideas, tensions, and notable changes across the day’s inputs.
	- Build the roundup around those themes, not a raw file list.
	- Opening thesis sentence must name the day’s central tension grounded in real context.

4. **Validate wikilinks**
	- Only link proper nouns and technical terms from `50. AI/02 Terminologies/`.
	- Validate: `obsidian vault=”Ataraxia” search query=”TERM” path=”50. AI/02 Terminologies” format=json limit=10`
	- Do NOT link arbitrary sentences or phrases found inside source files.
	- Target: 8+ validated wikilinks (15+ is excellent).

5. **Write the roundup section**
	- Append to or update the daily note at `10. Time/01 Daily Notes/YYYY-MM-DD.md`.
	- Each per-source section: thematic title (not raw filename), source attribution, one grounded quote or evidence fragment, 2-5 sentences of unique analysis with validated links, connection to another source or the day’s theme.
	- Never copy structural elements from source files (TL;DR callouts, ## Summary headings, Mermaid diagrams) — extract only quotes and claims.

6. **Verify coverage**
	- Confirm: 4+ sources, 8+ validated wikilinks, 2+ cross-source connections, 60+ output lines.
	- Confirm every source section corresponds to a file that was successfully read.

## Common Rationalizations
| Rationalization | Reality |
|---|---|
| “A file list is close enough to a roundup.” | A roundup synthesizes themes, not enumerates inputs. |
| “I found the source name so it must exist.” | Every source must be read via `obsidian read` before inclusion — hallucinated sources are a critical failure. |
| “Wikilinks from inside source files are fine.” | Only link terms validated in `50. AI/02 Terminologies/` — random sentence fragments as wikilinks are invalid. |
| “obsidian search found everything.” | Always supplement with `obsidian files` folder sweeps — search misses recently created files. |

## Red Flags
- Any per-source section written for a file that was not successfully read (hallucinated source)
- Structural elements from source files (TL;DR, Mermaid, ## Summary) copied into the roundup body
- Wikilinks that are not validated against `50. AI/02 Terminologies/`
- Fewer than 4 sources or fewer than 8 validated wikilinks
- Output is a file list instead of a thematic synthesis
- Only `obsidian search` used for discovery (no folder sweeps)

## Verification
After completing the skill’s process, confirm:
- [ ] Target date is explicit
- [ ] Every included source was confirmed readable via `obsidian read`
- [ ] Source discovery used both `obsidian search` and `obsidian files` folder sweeps
- [ ] 4+ real sources (6+ is good, 8+ is excellent)
- [ ] 8+ validated wikilinks from `50. AI/02 Terminologies/` (15+ is excellent)
- [ ] 2+ explicit cross-source connections in the synthesis
- [ ] 60+ output lines (100+ is good, 125+ is excellent)
- [ ] No template leakage from source files
- [ ] No repeated filler phrases across sections
- [ ] Roundup written into `10. Time/01 Daily Notes/YYYY-MM-DD.md`
