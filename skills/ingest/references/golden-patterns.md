---
aliases: []
tags: []
status: done
date_created: 2026-03-27
date_modified: 2026-04-01
---
# YouTube Clipping Golden Patterns

Derived from 2 Opus golden references:
- W 를 찾아서 (98KB, 397 줄, 11 chapters) — 박경철 강연
- 테슬라 반도체 만든다 (20KB, 146 줄, 5 chapters) — 일론 머스크 발표

## Core Principle: Every Sentence Must Appear

This is the most important rule. The clipping is a REWRITE, not a summary.

- Every sentence the speaker said must appear in the output
- Rewrite as written Korean prose (문어체) — remove only filler words and stutters
- Examples, anecdotes, statistics, and Q&A are preserved verbatim in rewritten form
- If the speaker said "20 GW per year" or "Jensen Wong said he had never seen anything built so fast" — those specific details MUST appear

### What "every sentence" Looks Like in Practice

**Transcript:** "So we either build the terafab or we do not have the chips and we need the chips."
**Good (문어체 rewrite):** " 결국 테라팹을 직접 짓든지, 아니면 칩 없이 가든지 둘 중 하나이며, 칩은 반드시 필요하다고 그는 말한다."
**Bad (summary):** " 머스크는 칩이 필요하다고 말했다." (← 원문의 양자택일 구조가 사라짐)

### Size Benchmarks
- 10-15 분 영상 → 80-150 줄, 10-25KB
- 30-60 분 영상 → 250-400 줄, 50-100KB
- Output 이 이 범위보다 현저히 작으면 요약한 것 — 재확인 필요

### Chapter Floors by Duration
- 10-20 분 → 3+
- 20-40 분 → 4+
- 40-60 분 → 6+
- 60 분 + → 8+

`W를 찾아서` 는 11 chapters 다. 긴 강연형 영상이 2-3 chapters 로 끝나면 대체로 summary-grade output 이다.

## 문어체 Conversion Rules

| Spoken (구어체) | Written (문어체) |
|----------------|----------------|
| ~거든요, ~잖아요 | ~이기 때문이다, ~는 점이다 |
| 그래서 뭐 | 따라서 |
| 진짜 대박인 게 | 주목할 만한 점은 |
| ~했다고 | ~했다고 밝혔다 / ~했다고 설명한다 |
| 어 그러니까 | (삭제 — filler) |

Keep the speaker voice: if they are humorous, the prose should feel witty. If formal, keep formal.

## Wikilink Validation Flow

After writing all chapters, scan for linkable entities:
1. People: check with `obsidian vault=Ataraxia search query="PERSON" path="70. Collections/01 People" format=json limit=10`
2. Concepts: check with `obsidian vault=Ataraxia search query="TERM" path="50. AI/02 Terminologies" format=json limit=10`
3. Use alias syntax for natural reading: `[[Artificial Intelligence (AI)|AI]]`
4. First occurrence per section only
5. Target: >= 5 validated wikilinks per clipping
6. Skip generic words (데이터, 기술, 시스템) — only link proper nouns and established terms

## Anchor Coverage

Every clipping needs visible anchor coverage, not just topical similarity.

Use three anchor families:
1. **Title anchors** — numbers, titular phrases, framing hooks
2. **Transcript anchors** — repeated motifs and concrete wording from the talk
3. **Narrative anchors** — anecdotes, examples, named entities, memorable scenes

Examples:
- If a title says `13억 날리고`, the note should still visibly retain that framing instead of dissolving into generic “사업은 구조가 중요하다”.
- If the talk revolves around `W`, `백수 친구`, `한메일`, and `시골의사`, those narrative beats should survive in the body.

## Frontmatter Standard

The authoritative templates live in `assets/{video,article}-{raw,processed}.template.md`.
This example shows the **processed** video frontmatter shape. The `source:` field is a
wikilink to the raw note — NOT the URL. The URL stays in the raw note's `source_url:`.

```yaml
---
aliases: []
author:
  - "[[Channel People Note]]"
speaker:
  - Speaker Name
title: "Title"
description: "{{one_line_description}}"
source: "[[raw_note_title]]"
image: "https://img.youtube.com/vi/VIDEO_ID/maxresdefault.jpg"
tags:
  - reference
  - reference/video
type: video
status: done
date_created: YYYY-MM-DD
date_modified: YYYY-MM-DD
date_published: YYYY-MM-DD
---
```

## Chapter Structure

Each chapter:
1. `### Descriptive Korean Title` (specific topic, not generic)
2. Full Korean prose (every sentence from that segment)
3. Mermaid diagram (flowchart TD/LR, max 5 nodes, no \n in labels)

Required section order for the note:
1. frontmatter
2. optional embed line
3. TL;DR callout
4. `## Summary`
5. `## 강의 전문`
6. `###` chapters

Do not use `## Chapters`.

## Quality Checklist (self-check Before saving)
- [ ] Every key statement from transcript present in prose?
- [ ] File size proportional to video length?
- [ ] Chapter count proportional to video length?
- [ ] Title/transcript/narrative anchors still visible?
- [ ] >= 5 validated wikilinks?
- [ ] Mermaid per chapter?
- [ ] TL;DR is a sharp insight (not generic)?
- [ ] No raw timestamps remain?
- [ ] No ICT:PENDING markers?
- [ ] Frontmatter complete?

## GPT-5.4 Model Limitations (discovered Through 6 iterations)

### Wikilink Non-Insertion (CONFIRMED MODEL LIMITATION)
- GPT-5.4 does NOT produce [[wikilink]] syntax in cron-generated output
- Tested: skill instructions, embedded dictionary, cron message injection, per-chapter integration
- All 6 iterations produced 0 body wikilinks
- Root cause: GPT-5.4 avoids [[...]] markdown syntax in long-form generation
- Solution: Post-processing enrichment step (EIC cron or dedicated wikilink enricher)

### Indirect Speech Tendency
- GPT-5.4 defaults to 3rd-person reporter voice (" 머스크는 ~라고 말한다 ")
- Negative instructions ("do NOT use indirect speech") make it WORSE (v3.1: 68 instances)
- Positive examples from golden references partially help (v3.2: reduced but regressed quality)
- Best result: v3.0 baseline without voice manipulation (8 instances, 8.0/10 score)
- Lesson: Do not fight the model default voice — accept it and focus on completeness

### Iteration History
| Version | Score | Indirect | Body Wikilinks | Key Change |
|---------|-------|----------|---------------|------------|
| v3.0 | 8.0 | 8 | 0 | baseline with every-sentence |
| v3.1 | 6.4 | 68 | 0 | anti-indirect-speech (REGRESSION) |
| v3.2 | 6.8 | 20+ | 0 | golden examples (partial recovery) |
| v3.3 | - | 8 | 0 | rollback to v3.0 base |
| v3.4 | - | 16 | 0 | per-chapter wikilinks (no effect) |
| v3.5 | - | 13 | 0 | pre-validated dictionary (no effect) |
| v3.5+embed | - | - | 0 | cron message injection (no effect) |

Best: v3.0 (8.0/10) — accept model defaults, focus on completeness
