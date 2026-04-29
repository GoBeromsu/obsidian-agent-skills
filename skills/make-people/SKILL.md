---
name: make-people
description: Creates or updates People notes in Ataraxia/70. Collections/01 People/<name>.md for contacts the user has met or wants to track (CRM-style). Use when the user says "make-people", "people 노트 만들어줘", "이 사람 노트로 정리해줘", "<이름> 노트 만들어줘", "이 사람 정리해줘", "방금 만난 사람 정리해줘", "people 노트 업데이트", "이 사람 이력 갱신해줘", "이 분 LinkedIn 받았는데 노트로 정리해줘". NOT for author/저자 notes (use the book skill), public figures the user has never met, or daily meeting logs (those go in Calendar daily notes).
---

# make-people

## Overview

Create or update CRM-style People notes in `70. Collections/01 People/`. Each note captures who a person is, where they were met, and links their authored works and event participations via Obsidian Bases queries. Supports both first-time creation and append-only updates to existing notes.

## Vault Access

Use the `obsidian-cli` skill for all note creation, edit, search, and property mutation inside the Ataraxia vault. Do not shell out to raw `cat`/`sed` on vault paths. See the `obsidian-cli` SKILL.md for the command surface and required preconditions (Obsidian must be running).

## When to Use

- User provides a name, LinkedIn URL, or brief context about a person they have met
- User says "people 노트 만들어줘", "이 사람 정리해줘", "방금 만난 사람 정리해줘"
- User shares a LinkedIn profile and wants it recorded: "이 분 LinkedIn 받았는데 노트로 정리해줘"
- User wants to update an existing note: "people 노트 업데이트", "이 사람 이력 갱신해줘"

**NOT for:**

- Author/저자 notes for books or papers — those go to `80. References/01 Book/` via the `book` skill
- Public figures the user has never interacted with — use a terminology or reference note instead
- Daily logs of a meeting — those belong in `Ataraxia/00. Calendar/` daily notes

## Process

### Step 1: Determine filename

- Korean name → `<한글이름>.md` (e.g., `송다인.md`)
- Non-Korean name → `<English Full Name>.md` with original casing (e.g., `Alex Demissie.md`)
- Person uses both scripts (e.g., `윤석원 (Dale Yoon)`) → use Korean filename; put the English name in `aliases`

### Step 2: Check for an existing note

```bash
obsidian vault="Ataraxia" read path="70. Collections/01 People/<filename>.md"
```

If the note exists, follow the **Update Mode** section instead of continuing here.

### Step 3: Compose frontmatter

```yaml
---
aliases: [<localized variations>, <other-script name if any>]
date_created: <YYYY-MM-DD>
date_modified: <YYYY-MM-DD>
source: <LinkedIn URL or other source URL — empty list [] if unknown>
description: <one-line who/what — optional but encouraged>
tags:
  - crm
type: people
organization: <org name or wikilink [[OrgName]], empty if unknown>
up:
moc: "[[207.01 Peoples]]"
---
```

Rules:
- `tags` must always include `crm`
- `type` must always be `people`
- `moc` must always be `"[[207.01 Peoples]]"`
- `source` is a scalar string (single URL) or list if multiple sources; use `[]` when unknown
- `organization` may be a plain string or a `[[wikilink]]`; leave empty if unknown

### Step 4: Compose body

The note body follows this structure. Replace `<filename-without-ext>` with the filename minus `.md` (e.g., `송다인`, `Zhanna Tlegenova`, `Alex Demissie`). The Korean blockquote labels are literal vault content and must appear verbatim. The `## Author` and `## Participant` sections each require a fenced `base` block.

**Header and LinkedIn line:**

```
# <Display Name>

- **LinkedIn**: [<handle>](<url>)
```

Omit the LinkedIn line entirely if no URL was provided.

**Basic Information section** — include only fields the user supplies, never invent:

```
## Basic Information

- 소속: ...
- 학연 / 배경: ...
```

**Notes section:**

```
## Notes

- [[<met-on-date> <project-or-context>]] 에서 만남
- (1–4 bullets from what the user said; preserve first-person observations verbatim)
```

**Author section** — the blockquote label and base block are required verbatim:

```
## Author

> 이 사람이 저자인 작품이나 노트들
```

Followed immediately by a fenced base block:

```
filters:
  or:
    - author.contains(link("<filename-without-ext>"))
views:
  - type: table
    name: Authored Works
    groupBy:
      property: type
      direction: ASC
    order:
      - file.name
      - type
      - date_created
    sort:
      - property: date_created
        direction: DESC
```

(The fence above opens with triple backticks + `base` and closes with triple backticks.)

**Participant section** — the blockquote label and base block are required verbatim:

```
## Participant

> 이 사람이 참여자인 프로젝트나 미팅들
```

Followed immediately by a fenced base block:

```
filters:
  or:
    - participants.contains(link("<filename-without-ext>"))
    - Participant.contains(link("<filename-without-ext>"))
views:
  - type: table
    name: Participated In
    order:
      - file.name
      - type
      - date_created
    sort:
      - property: date_created
        direction: DESC
```

(The fence above opens with triple backticks + `base` and closes with triple backticks.)

**References section:**

```
## References

> 이 사람이 언급된 모든 노트들
```

### Step 5: Create the note

```bash
obsidian vault="Ataraxia" create path="70. Collections/01 People/<filename>.md" content="<full note content>"
```

Use `\n` for newlines in the content string. Verify the note was created before concluding.

### Step 6: Verify

Run the verification checklist at the bottom of this skill.

## Update Mode

When the user wants to append new context to an existing People note:

1. Read the existing note:
   ```bash
   obsidian vault="Ataraxia" read path="70. Collections/01 People/<filename>.md"
   ```
2. Append new bullets to `## Notes` only — do not reorder existing bullets:
   ```bash
   obsidian vault="Ataraxia" append path="70. Collections/01 People/<filename>.md" content="\n- <new bullet>"
   ```
3. Bump `date_modified` to today:
   ```bash
   obsidian vault="Ataraxia" property:set name="date_modified" value="<YYYY-MM-DD>" path="70. Collections/01 People/<filename>.md"
   ```
4. Preserve `aliases`, `source`, and `organization` unless the user explicitly asks to change them.
5. If a new LinkedIn URL is provided and it differs from the existing one, ask the user before replacing.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I can invent plausible fields for Basic Information." | Only write fields the user actually provided. Invented data poisons the CRM. |
| "The LinkedIn line can stay even if no URL was given." | Omit the LinkedIn line entirely when no URL is supplied — a blank wikilink is worse than no line. |
| "I can use `mv` or the Write tool to create the file." | Always use `obsidian vault="Ataraxia" create` so Obsidian registers the file and backlinks resolve. |
| "The base blocks are optional boilerplate." | They are required. Without them, Bases queries for author and participant cross-references break. |
| "I can skip the `moc` field since it's just a link." | `moc: "[[207.01 Peoples]]"` is required on every People note — it is how the MOC aggregates contacts. |
| "For an update I can overwrite the whole file." | Use append + property:set. Never overwrite; existing observations would be silently lost. |
| "Public figures count as people notes." | Only people the user has personally interacted with belong in `01 People`. Use a terminology note for public figures. |

## Red Flags

- `type: people` or `tags: [crm]` missing from frontmatter
- `moc` field absent or points to the wrong note
- LinkedIn line present but contains no URL (empty brackets)
- `## Author` or `## Participant` base blocks missing
- `<filename-without-ext>` placeholder left literally in the base block filters instead of the actual name
- Write tool or `bash mv` used to create/rename vault notes instead of `obsidian-cli`
- Existing `## Notes` bullets reordered or deleted during an update

## Verification

After completing the workflow, confirm:

- [ ] File exists at `Ataraxia/70. Collections/01 People/<filename>.md` — verified with `obsidian vault="Ataraxia" read path="70. Collections/01 People/<filename>.md"`
- [ ] Frontmatter contains `type: people` and `tags: [crm]`
- [ ] `moc` field is `"[[207.01 Peoples]]"`
- [ ] LinkedIn line is present if and only if a URL was supplied; absent otherwise
- [ ] `## Author` base block filter references the correct `<filename-without-ext>` (not the placeholder literal)
- [ ] `## Participant` base block filter references the correct `<filename-without-ext>` in both `participants` and `Participant` branches
- [ ] `## Basic Information` contains only fields the user actually provided
- [ ] `## Notes` bullets reflect only what the user said — no invented observations
- [ ] Update flow only: `date_modified` bumped; existing bullets untouched; full-file overwrite not performed
