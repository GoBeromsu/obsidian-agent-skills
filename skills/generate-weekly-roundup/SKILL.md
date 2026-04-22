---
name: generate-weekly-roundup
description: Use when you need to synthesize a week of activity into a weekly roundup. Reads GDR daily roundup outputs as the primary distilled input, falls back to raw daily notes for days without a GDR, mines cross-day patterns (recurring concerns, repeated mistakes, resistances, pivots), and synthesizes a directional trajectory for the week. Writes a dedicated GWR note under `50. AI/03 Roundup/Weekly/` and links it back from the weekly note's `roundup:` frontmatter field, mirroring how GDR notes are linked from daily notes. Use for week-scoped synthesis; do not use for single-day synthesis — use `generate-daily-roundup` for that. Trigger keywords include `gwr`, "weekly roundup", "generate weekly roundup".
---

# generate-weekly-roundup

## Overview

Generate a weekly roundup by reading each day's GDR output as the primary distilled source, supplemented by raw daily notes for days without a GDR. The output is not a summary of summaries — it is a cross-day pattern analysis that names what recurred, what failed repeatedly, and what direction the week's arc implies. The synthesis is written as its own note at `50. AI/03 Roundup/Weekly/YYYY-MM-DD~YYYY-MM-DD - GWR.md`, and the weekly note's `roundup:` frontmatter field is set to point at it — so the weekly note stays a plan/index surface and the GWR note carries the synthesis, exactly like daily notes + GDR notes.

## Vault Access

Use the `obsidian-cli` skill for all note creation, edit, search, and property mutation inside the Ataraxia vault. Do not shell out to raw `cat`/`sed` on vault paths. See the `obsidian-cli` SKILL.md for the command surface and required preconditions (Obsidian must be running).

## When to Use

- Use when the user wants a weekly synthesis across multiple days
- Use when cross-day patterns (recurring concerns, repeated mistakes, directional drift) need to be surfaced
- Use when week-scoped rather than single-day synthesis is needed
- Do not use for single-day synthesis — use `generate-daily-roundup` for that

## Process

1. **Define the week scope**
   - Resolve the target week (ISO week: YYYY-Www, e.g. `2026-W16`) and the Sun–Sat date range that the vault's weekly note uses.
   - Read the weekly note: `obsidian vault="Ataraxia" read path="10. Time/02 Weekly Notes/YYYY-Www.md"` — the base query at the bottom of the weekly note tells you the exact date range to use.

2. **Collect weekly inputs**
   - For each day in the week, check the daily note frontmatter for a `roundup:` field.
     - If set: read the GDR output note referenced there — this is the primary distilled input for that day.
     - If not set or the linked GDR file is missing/trashed: read the raw daily note `10. Time/01 Daily Notes/YYYY-MM-DD.md` directly and note the fallback in the Source Coverage table.
   - Also sweep `15. Work/01 Project/` and `80. References/` for notes created or modified that week.

3. **Mine cross-day patterns**
   - Scan all inputs and explicitly identify:
     - **Recurring concerns** — topics, anxieties, or questions that appeared on ≥2 separate days
     - **Repeated mistakes or anti-patterns** — errors, omissions, or behaviors the user acknowledged going wrong more than once
     - **Resistances** — things consistently avoided, postponed, or struggled against across the week
     - **Pivots** — moments where thinking visibly shifted direction mid-week
   - These patterns become the skeleton of the synthesis. Do not start writing before completing this step.

4. **Extract themes**
   - Organize the roundup around the patterns found in Step 3.
   - Connect at least two cross-day threads in synthesis sentences.
   - Do not structure the output as a date-by-date dump.

5. **Validate wikilinks**
   - Only link proper nouns, technical terms, or concrete vault notes (daily notes, project notes, terminology) that actually exist.
   - Validate terminology links: `obsidian vault="Ataraxia" search query="TERM" path="50. AI/02 Terminologies" format=json limit=10`
   - For daily note, project note, or review note references, confirm the target file exists before inserting the link.
   - Do not link arbitrary phrases or sentence fragments.

6. **Write the GWR note**
   - Create a new note at `50. AI/03 Roundup/Weekly/YYYY-MM-DD~YYYY-MM-DD - GWR.md`, where the date range is the week's Sun–Sat span (e.g. `2026-04-12~2026-04-18 - GWR.md`).
   - Required frontmatter (mirrors the existing GWR convention):

     ```yaml
     ---
     agent: GWR
     aliases: []
     date_range: YYYY-MM-DD~YYYY-MM-DD
     date_created: YYYY-MM-DD
     date_modified: YYYY-MM-DD
     tags: []
     type: weekly-roundup
     up: "[[YYYY-WwwW]]"
     week: "[[YYYY-WwwW]]"
     ---
     ```

   - Required body sections, in this order:
     - `# YYYY-MM-DD~YYYY-MM-DD Weekly Roundup`
     - `## Source Coverage` — table with Date · Day · Source Type · File link · Status. Mark fallback rows explicitly (e.g. `⚠️ Fallback`) when a GDR was missing and the raw daily note was read instead.
     - **Opening thesis paragraph** — names the week's central cross-day tension or pattern, grounded in evidence from Step 3, not a generic theme label.
     - **Per-pattern sections** — each named pattern from Step 3 becomes its own `### Pattern N — ...` section; cite which days and what evidence.
     - `### Direction Signal` — required closing section. Given the week's patterns, name the trajectory being implied or resisted. This is not a prediction — it is an inference from the evidence. Format: one short paragraph that completes the sentence "This week's arc points toward ___." Include a shadow-direction note when resistances point somewhere the surface narrative does not.

7. **Link the GWR note from the weekly note**
   - Open `10. Time/02 Weekly Notes/YYYY-WwwW.md`.
   - In its frontmatter, set `roundup: "[[YYYY-MM-DD~YYYY-MM-DD - GWR]]"` — exactly like daily notes set `roundup: "[[YYYY-MM-DD - GDR]]"`.
   - Update `date_modified` to today.
   - Do not write the synthesis body into the weekly note itself — the weekly note is a plan/index surface; the GWR note carries the content.

8. **Verify coverage**
   - Confirm all days in the week were checked.
   - Confirm GDR outputs were used as primary source where available, and fallbacks are flagged in Source Coverage.
   - Confirm the output is pattern-driven synthesis, not a stitched list of daily sections.
   - Confirm the weekly note's frontmatter `roundup:` field points at the new GWR note.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "GDR already synthesized each day — weekly is just a meta-summary." | Cross-day pattern detection (recurring errors, escalating concerns, weekly drift) is invisible within a single day. GWR sees the week's gradient; GDR cannot. |
| "Weekly means I can just concatenate the daily GDR outputs." | Concatenation is not synthesis. The value of GWR is in the patterns that span days, not in restating each day's output. |
| "If the daily roundup exists, I don't need to read the raw daily note." | For days *without* a GDR output, or where the linked GDR file is missing/trashed, the raw daily note is the only source — it must be read directly and flagged as a fallback. |
| "No clear direction emerged from the week." | Pattern absences, repeated resistances, and consistently unanswered questions are directional signals. The Direction Signal must be written even when the direction is "stuck" or "avoiding." |
| "I'll just append the synthesis into the weekly note to save a file." | Mixing synthesis into the plan/index surface breaks symmetry with the daily-note-to-GDR relationship and makes the roundup harder to discover, backlink, and reuse. The weekly note links to the GWR note; it does not contain it. |
| "If the GWR note exists, the weekly note doesn't need updating." | The weekly note's `roundup:` field is the discovery path. Without updating it, future reads and graph views cannot find the synthesis. |

## Red Flags

- Synthesis body written into the weekly note instead of a dedicated GWR note
- Weekly note's `roundup:` frontmatter field left empty after GWR is produced
- GWR note created without the required frontmatter (`agent: GWR`, `date_range`, `type: weekly-roundup`, `week`/`up` links)
- Output is mostly a stitched list of GDR section summaries without cross-day analysis
- Pattern Mining step skipped — no recurring concerns or mistakes named
- Direction Signal section absent or replaced with a generic theme label
- Weekly scope is implicit (no date range in the filename or frontmatter)
- Source Coverage table missing or fallbacks not flagged
- GDR outputs not read; raw daily notes used even when `roundup:` is set
- Wikilinks inserted without checking that the target file exists

## Verification

After completing the skill's process, confirm:

- [ ] Target week is explicit as both an ISO week (YYYY-Www) and a Sun–Sat date range
- [ ] All days in the week checked; GDR output used as primary source where `roundup:` frontmatter is set on the daily note
- [ ] Raw daily note read (and flagged as fallback) for days without a GDR output or where the GDR file is missing/trashed
- [ ] Weekly note read before writing
- [ ] Pattern Mining completed: ≥1 recurring concern and ≥1 repeated mistake or resistance named with evidence
- [ ] Output organized around patterns, not dates
- [ ] At least two cross-day threads connected in synthesis sentences
- [ ] Direction Signal paragraph present and grounded in evidence
- [ ] All wikilinks point at files that actually exist in the vault
- [ ] Synthesis written to `50. AI/03 Roundup/Weekly/YYYY-MM-DD~YYYY-MM-DD - GWR.md` with required frontmatter
- [ ] Weekly note's frontmatter `roundup:` field updated to `[[YYYY-MM-DD~YYYY-MM-DD - GWR]]`
- [ ] Weekly note's `date_modified` bumped to today
