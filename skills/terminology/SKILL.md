---
name: terminology
description: >
  Create, rewrite, and consolidate PKM terminology notes in
  50. AI/02 Terminologies/. Handles variant detection across the vault,
  boilerplate cleanup ("기존 노트 필기" absorption), and duplicate merging via obsidian CLI.
  Use when: (1) /terminology, (2) "용어 노트 만들어줘" or "노트 만들어줘" for a concept,
  (3) user learned a term and wants to document it, (4) "검색해보고 노트 만들어줘",
  (5) user wants to consolidate duplicate notes about a concept.
---

# terminology

## Overview

Create or maintain terminology notes in `50. AI/02 Terminologies/`. The SSOT for this skill's prompt and template is `50. AI/04 Skills/terminology/SKILL.md`. The canonical template is at `references/template.md` (exact extraction from the SSOT prompt). Handles variant detection, boilerplate cleanup, and duplicate merging via obsidian CLI. Produces one note; does not modify neighboring notes.

## Vault Access

Use the `obsidian-cli` skill for all note creation, edit, search, and property mutation inside the Ataraxia vault. Do not shell out to raw `cat`/`sed` on vault paths. See the `obsidian-cli` SKILL.md for the command surface and required preconditions (Obsidian must be running).

## When to Use

- Use when the user wants a terminology note for a concept
- Use when duplicate or variant concept notes need consolidation
- Use when a concept note accumulated "기존 노트 필기" that needs to be absorbed into proper sections
- Use when the user says "용어 노트", "노트 만들어줘", or invokes `/terminology`
- Do not use for general essay writing or unrelated document drafting

## Process

### Step 1: Assess

Run a four-pronged variant scan in parallel:

```
1. Glob: **/*[term]*                                     — filename matches
2. obsidian vault="Ataraxia" backlinks file="[term]"     — wikilink references (alias-resolved)
3. Grep: "\[\[.*term.*\]\]"                              — exact wikilink pattern matches
4. qmd semantic-first recall                             — qmd query (vec / lex+vec), not BM25-only qmd search
```

For qmd-driven discovery, treat `qmd search` as **BM25-only** and use it only for exact lexical verification after discovery. Primary recall should come from `qmd query`.

Evaluate 2–3 query shapes before settling on candidates for broad concepts:

```bash
# Hybrid default: best first pass for bilingual vault discovery
qmd query $'lex: "software engineering" "소프트웨어 공학"\nvec: Find semantically relevant notes for software engineering in this bilingual Korean and English vault, including terminology notes, personal notes, and video notes.\nintent: terminology note discovery for canonical concept consolidation' -c obsidian -n 10

# Semantic-only fallback: use when vocabulary is uncertain or exact wording is weak
qmd query $'vec: Find semantically relevant notes for software engineering in this bilingual Korean and English vault, including terminology notes, personal notes, and video notes.\nintent: terminology note discovery for canonical concept consolidation' -c obsidian -n 10

# BM25-only control: use to compare recall, not as the default discovery path
qmd search 'software engineering 소프트웨어 공학' -c obsidian
```

For bilingual vault terms, run all three query variants before choosing recall candidates:
- English only
- Korean only
- Mixed English + Korean

For broad concepts such as `programming`, `coding`, and `software engineering`, this bilingual comparison is mandatory, not optional.

When the concept is broad or socially overloaded, add a corpus hint in the query text rather than relying on BM25 alone:
- `video notes`
- `personal notes`
- `terminology notes`

Initial evaluation on `programming`, `coding`, and `software engineering` showed:
- BM25 mixed queries over-favor exact compound titles and near-string matches
- generic semantic queries can drift into meta/config notes if the prompt is too broad
- hybrid `lex + vec` with bilingual wording and corpus hints is usually the best default for terminology discovery
- video-biased retrieval works well for some concepts (`programming`, `software engineering`) but can be noisy for overloaded terms like `coding`

Classify each found note:

| Type | Signal | Action |
|---|---|---|
| Empty stub | Only frontmatter, no body | Add filename to canonical `aliases` → `obsidian delete` |
| Boilerplate | "정합성을 위해", "상호참조 항목" | Discard auto-generated sections |
| Has 기존 노트 필기 | `## 기존 노트 필기` header present | Priority source — absorb hand-written content below header |
| Real content | Hand-written, specific insights | Read fully, merge into draft |

**Canonical location**: `50. AI/02 Terminologies/[Filename Convention].md`

**Filename convention**:
- Has common acronym → `Full English Term (ACRONYM).md`
- No acronym → `English Term.md`
- Korean names go in `aliases` only — never in the filename

**Obsidian search pattern**:
```bash
obsidian vault="Ataraxia" search query="TERM" path="50. AI/02 Terminologies" format=json limit=10
```

### Step 2: Research

Run applicable branches in parallel:

- **WebSearch** (skip if source provided or personally defined): `"[TERM] definition mechanism application"` — run defuddle on promising URLs
- **Personal experience scan**: flag personal notes (journals, CMDs, dated entries, video notes) from semantic-first qmd results; read top 2–3 for personal connection to the concept
- **Query-pattern check**: for broad concepts, compare BM25 vs semantic vs hybrid retrieval across English, Korean, and mixed queries before trusting the first result set
- **Final link verification**: before inserting any final wikilink, resolve the exact target with `obsidian file` (or equivalent exact vault lookup) after semantic discovery

Skip WebSearch when source material is provided directly or the term is personally defined.

### Step 3: Draft

Read `references/template.md` for frontmatter schema, body structure, and citation rules.

**When existing note has "기존 노트 필기" pattern**:
1. Discard all auto-generated content above the header (boilerplate markers: "정합성을 위해 기초 근거를 정리한다", "개념적 경계가 겹치는 상호참조 항목", placeholder TL;DR that restates the definition)
2. Absorb hand-written content below `## 기존 노트 필기` — Literature Review entries, code examples, Related Concepts with real descriptions
3. Remove the "기존 노트 필기" header — restructure content into proper template sections

**Draft structure**:

1. **Definition block**: one paragraph + 2–4 key characteristics
2. **Literature Review** (≥2 entries): natural Korean opening per entry explaining why this source and what delta it adds; claim-tree body, max depth 3
3. **Personal Insights** (always present): personal notes found → `### [[VaultNoteTitle]]` + free-form body
4. **Related Concepts**: wikilinks only, each discovered via `qmd query`, checked across bilingual variants when the concept is broad, and then exact-verified with `obsidian file` before insertion

Optional sections: `## Examples` when concrete examples are essential; `## Etymology / Origin` when origin is a key to understanding.

### Step 4: Verify

- [ ] Frontmatter: `aliases`, `moc`, `date_created`, `date_modified`, `tags` (PascalCase + `terminology`), `type`
- [ ] TL;DR: insight or trade-off, not a definition restatement
- [ ] Literature Review: ≥2 entries, each opening = natural Korean delta (no formula)
- [ ] `## Personal Insights` present
- [ ] Discovery used semantic-first qmd query patterns; BM25-only lookup was not the sole recall method
- [ ] Broad bilingual concepts were checked with English / Korean / mixed queries before choosing recall candidates
- [ ] All wikilinks exact-verified after semantic discovery; all external URLs defuddle-confirmed
- [ ] No boilerplate phrases remain ("정합성을 위해", "상호참조 항목")

### Step 5: Publish

Write the note with the Write tool at the canonical path.

**Variant cleanup** (for each non-canonical variant found in Step 1):

1. Add variant filename (sans `.md`) to canonical note's `aliases`
2. Get backlinks **before** deleting:
   ```bash
   obsidian vault="Ataraxia" backlinks file="VariantName"
   ```
3. Delete the variant and permanently remove from `.trash/`:
   ```bash
   obsidian vault="Ataraxia" delete file="VariantName"
   rm -f .trash/VariantName.md
   ```
4. Update wikilinks explicitly (`[[OldName]]` → `[[NewCanonicalName|OldName]]`) — alias auto-resolve is unreliable
5. Verify: `obsidian vault="Ataraxia" backlinks file="NewCanonicalName"` must show all updated references

**Re-index after publish**:
```bash
qmd update
```

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "The first matching note is probably canonical." | Concept notes drift; classify all variants before choosing the survivor. |
| "I can add related links from memory." | All wikilinks must be qmd-verified before insertion. |
| "qmd search is enough because the term is obvious." | `qmd search` is BM25-only; broad bilingual concepts often need semantic or hybrid recall to surface the right notes. |
| "External sources are good enough; vault context is redundant." | Personal vault notes are often the highest-value differentiator in a terminology note. |
| "I'll skip the backlink check before deleting the variant." | After deletion, backlinks are no longer queryable — check first. |

## Red Flags

- Variant notes deleted without reading their content first
- Related concepts added without qmd verification
- Only BM25 lookup used for broad concept discovery in a bilingual vault
- Boilerplate phrases ("정합성을 위해", "상호참조 항목") left in the output note
- Wikilinks inserted from memory without vault confirmation
- "기존 노트 필기" content discarded instead of absorbed
- Note created at a path other than `50. AI/02 Terminologies/`

## Verification

After completing the workflow, confirm:

- [ ] Four-pronged variant scan ran in parallel (Glob + backlinks + Grep + qmd)
- [ ] qmd recall strategy was evaluated semantically for broad terms, not treated as BM25-only search
- [ ] All variants classified before any delete/merge action
- [ ] "기존 노트 필기" content absorbed, not discarded
- [ ] All wikilinks in Related Concepts are qmd-verified
- [ ] Canonical note written to `50. AI/02 Terminologies/`
- [ ] Variant notes deleted and removed from `.trash/`
- [ ] Explicit wikilink updates applied to all backlink sources
- [ ] `qmd update` run after publish
