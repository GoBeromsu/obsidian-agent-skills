---
name: gwr
description: Use when you need to synthesize a week of activity into a weekly roundup. Reads GDR daily roundup outputs as the primary distilled input, falls back to raw daily notes for days without a GDR, mines cross-day patterns (recurring concerns, repeated mistakes, resistances, pivots), and synthesizes a directional trajectory for the week. Use for week-scoped synthesis; do not use for single-day synthesis — use `gdr` for that.
---

# gwr

## Overview

Generate a weekly roundup by reading each day's GDR output as the primary distilled source, supplemented by raw daily notes for days without a GDR. The output is not a summary of summaries — it is a cross-day pattern analysis that names what recurred, what failed repeatedly, and what direction the week's arc implies. Writes into the weekly note at `10. Time/02 Weekly Notes/YYYY-Www.md`.

## When to Use

- Use when the user wants a weekly synthesis across multiple days
- Use when cross-day patterns (recurring concerns, repeated mistakes, directional drift) need to be surfaced
- Use when week-scoped rather than single-day synthesis is needed
- Do not use for single-day synthesis — use `gdr` for that

## Process

1. **Define the week scope**
   - Resolve the target week (ISO week: YYYY-Www, e.g. `2026-W16`).
   - Read the weekly note: `obsidian vault="Ataraxia" read path="10. Time/02 Weekly Notes/YYYY-Www.md"`

2. **Collect weekly inputs**
   - For each day Mon–Sun, check the daily note frontmatter for a `roundup:` field.
     - If set: read the GDR output note referenced there — this is the primary distilled input for that day.
     - If not set: read the raw daily note `10. Time/01 Daily Notes/YYYY-MM-DD.md` directly.
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
   - Only link proper nouns and technical terms from `50. AI/02 Terminologies/`.
   - Validate: `obsidian vault="Ataraxia" search query="TERM" path="50. AI/02 Terminologies" format=json limit=10`
   - Do not link arbitrary phrases or sentence fragments.

6. **Write the weekly roundup**
   - Append to or update the weekly note at `10. Time/02 Weekly Notes/YYYY-Www.md`.
   - **Opening thesis**: names the week's central cross-day tension or pattern — grounded in evidence from Step 3, not a generic theme label.
   - **Per-pattern sections**: each named pattern from Step 3 becomes a section; cite which days and what evidence.
   - **Direction Signal** (required closing section): given the week's patterns, name the trajectory being implied or resisted. This is not a prediction — it is an inference from the evidence. Format: one short paragraph that completes the sentence "This week's arc points toward ___."

7. **Verify coverage**
   - Confirm all 7 daily notes were checked.
   - Confirm GDR outputs were used as primary source where available.
   - Confirm the output is pattern-driven synthesis, not a stitched list of daily sections.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "GDR already synthesized each day — weekly is just a meta-summary." | Cross-day pattern detection (recurring errors, escalating concerns, weekly drift) is invisible within a single day. GWR sees the week's gradient; GDR cannot. |
| "Weekly means I can just concatenate the daily GDR outputs." | Concatenation is not synthesis. The value of GWR is in the patterns that span days, not in restating each day's output. |
| "If the daily roundup exists, I don't need to read the raw daily note." | For days *without* a GDR output, the raw daily note is the only source — it must be read directly. |
| "No clear direction emerged from the week." | Pattern absences, repeated resistances, and consistently unanswered questions are directional signals. The Direction Signal must be written even when the direction is "stuck" or "avoiding." |
| "If the note exists, the roundup must be fine." | The content still needs a pattern-mining and synthesis check against the full week's inputs. |

## Red Flags

- Output is mostly a stitched list of GDR section summaries without cross-day analysis
- Pattern Mining step skipped — no recurring concerns or mistakes named
- Direction Signal section absent or replaced with a generic theme label
- Weekly scope is implicit (no ISO week identifier)
- GDR outputs not read; raw daily notes used even when `roundup:` is set
- Wikilinks inserted without validation against `50. AI/02 Terminologies/`
- Output written somewhere other than `10. Time/02 Weekly Notes/YYYY-Www.md`

## Verification

After completing the skill's process, confirm:

- [ ] Target week is explicit (ISO format YYYY-Www)
- [ ] All 7 daily notes checked; GDR output used as primary source where `roundup:` frontmatter is set
- [ ] Raw daily note read for days without a GDR output
- [ ] Weekly note read before writing: `10. Time/02 Weekly Notes/YYYY-Www.md`
- [ ] Pattern Mining completed: ≥1 recurring concern and ≥1 repeated mistake or resistance named with evidence
- [ ] Output organized around patterns, not dates
- [ ] At least two cross-day threads connected in synthesis sentences
- [ ] Direction Signal paragraph present and grounded in evidence
- [ ] All wikilinks validated against `50. AI/02 Terminologies/`
- [ ] Roundup written into `10. Time/02 Weekly Notes/YYYY-Www.md`
