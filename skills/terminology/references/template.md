# Terminology Note Template

## Frontmatter

```yaml
---
aliases: [Korean alias, Korean alias without spaces]
moc: "[[📚 104 Terminologies]]"
date_created: YYYY-MM-DD
date_modified: YYYY-MM-DD
tags:
  - DomainTag          # PascalCase domain (e.g. Antifragile, NeuroscienceNote)
  - RelatedTermTag     # PascalCase related concept (e.g. BarbellStrategy)
  - terminology        # always include
type: terminology
---
```

## Body

```markdown
## ENGLISH TERM (ACRONYM / Korean)

> [!abstract] TL;DR
> [1–2 sentences capturing the essential insight — practical framing, trade-offs, or mechanisms. Not a restatement of the definition.]

[Definition and usage context — one paragraph. Inline wikilink on first mention of source note if single source: [[NoteTitle|natural sentence text.]] For external source: ends with [(Author, Year)](URL)]

- [Key characteristic or example 1]
- [Key characteristic or example 2]
- [Key characteristic or example 3 — optional]

## Literature Review

### [[VaultNoteTitle]]   ← internal: wikilink directly in heading

[이 source를 포함한 이유를 자연스러운 한국어로 서술한다. 다른 source와 구별되는 고유한 기여(delta)가 반드시 포함되어야 한다 — 고정 문형 없이, 독자에게 "이 source만 읽으면 이걸 얻는다"는 것이 명확하게 전달되면 된다. 예: "Flavell의 논문은 메타인지 연구의 출발점이다. 산발적인 관찰들을 네 구성요소로 체계화했으며, 이후 모든 연구가 이 틀을 기반으로 한다."]

- [Main claim/argument.]
	- [Supporting sub-claim.]
		- [Depth 3 precision, only when needed.]
- [Second main claim.]
	- [Supporting sub-claim.]
		- [Depth 3 precision, only when needed.]

### [Actual Article or Book Title](URL)   ← external: use the real title, not Author+Year

[이 source를 포함한 이유를 자연스러운 한국어로 서술한다. 다른 source와 구별되는 고유한 기여(delta)가 반드시 포함되어야 한다 — 고정 문형 없이, 독자에게 "이 source만 읽으면 이걸 얻는다"는 것이 명확하게 전달되면 된다. 예: "Flavell의 논문은 메타인지 연구의 출발점이다. 산발적인 관찰들을 네 구성요소로 체계화했으며, 이후 모든 연구가 이 틀을 기반으로 한다." [(Author, Year)](URL)]

- [Main claim/argument.]
	- [Supporting sub-claim.]
		- [Depth 3 precision, only when needed.]
- [Second main claim.]
	- [Supporting sub-claim.]
		- [Depth 3 precision, only when needed.]

## Personal Insights

### [[PersonalVaultNoteTitle]]   ← 반드시 실제 vault 노트 wikilink; 존재하지 않는 노트는 사용 불가

[구조보다 진정성 우선으로 개인 경험과 생각을 자유롭게 서술한다. 인용문(`>`), 불릿, 산문 모두 허용.]

## 관련 개념 (Related Concepts)

- [[Parent Concept (한글)]] #DomainTag
  - [One-line: how this term relates to the parent]
- [[Sibling Term (한글)]] #DomainTag
  - [One-line: relationship]
- [[Source Book Title]] #독서
  - [One-line: this term appears in / introduced by this book]
```

## Citation Rules

Two citation formats — external and internal — serve different structural roles.

### External Sources — APA-style Inline Hyperlink

```
[(Author, Year)](https://doi-or-url)
[(Author & Author, Year)](https://doi-or-url)
[(Organization, n.d.)](https://url)
```

- **Always verify URLs before citing** — never fabricate DOIs

### Internal Sources — Vault Wikilinks

Used when a vault note is **referenced to support or build upon a point** in the body. The linked text IS the expression from that note — not a paraphrase.

```markdown
[[은혜의 순간은 내가 잘 살아낸 하루가 쌓여서 오는게 아니라 그냥 갑자기 선물로 냅다 온다|은혜는 누적된 노력의 보상이 아니라 갑자기 선물로 온다.]] 이것은 은혜의 선행성을 보여준다.
```

Use anywhere in the body where you're citing a vault note inline.

## LaTeX

Use inline `$…$` or block `$$…$$` LaTeX anywhere in the body when it clarifies a concept — formulas, inequalities, notation. No restriction on location; use only when it genuinely aids understanding.

## Korean-English Mixing Rules

| Situation | Rule | Example |
|-----------|------|---------|
| First appearance | `English(Korean)` or `Korean(English)` — once only | antifragility(안티프래질리티) |
| Re-appearance | One language only, drop parentheses | antifragility |
| Per sentence | Max 1 parenthetical | ✓ |
| Academic terms | Always English | convexity, receptor, pathway |
| General verbs | Korean | 조절하다, 증가시키다, 형성한다 |
