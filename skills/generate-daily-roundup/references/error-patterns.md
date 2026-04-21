# GDR Error Patterns & Lessons Learned

## Pattern 1: Template Leakage (v2, FIXED in v3)
**Symptom**: Source file TL;DR callouts, ## Summary sections, Mermaid diagrams copied into roundup body
**Root cause**: Agent reads source file and pastes structural elements instead of extracting only quotes and claims
**Fix**: Added anti-template-leakage rules in Phase 4 — explicit list of what NEVER to include

## Pattern 2: Repetitive Template Phrases (v2, FIXED in v3)
**Symptom**: Every per-source section contains identical phrase "X는 Y를 단순한 정보가 아니라 생활의 리듬 문제로 다룬다"
**Root cause**: Agent fell into a template pattern instead of writing unique analysis
**Fix**: Added anti-repetition rule requiring unique analysis per section

## Pattern 3: Source Discovery Incomplete (v1, IMPROVED in v2)
**Symptom**: Only 3/5 sources found when obsidian search alone used
**Root cause**: obsidian search query can miss files, especially recently created ones
**Fix**: Added `obsidian files` folder sweeps across project/area/QT/reference folders and merged them with `obsidian search` results

## Pattern 4: Empty/Test Files Included (v1-v2, FIXED in v3)
**Symptom**: "2025-11-11 Test Article" (empty body) included as a full section
**Root cause**: No content validation before including a source
**Fix**: Added 200-char minimum + "Test" keyword filter

## Pattern 5: Invalid Wikilinks (v2, FIXED in v3)
**Symptom**: Random sentences linked as wikilinks (e.g., [[왜 이 문제는 독립성이 아니라 조건부 확률로 풀었는가]])
**Root cause**: Agent linked text found inside source files, not vault terminology notes
**Fix**: Strict rule: only link proper nouns, technical terms from 02 Terminologies/

## Pattern 6: Low Terminology Wikilink Density (v3, IMPROVING)
**Symptom**: Only 1-2 terminology links when Opus achieves 6-8
**Root cause**: Agent only links terms explicitly mentioned, not conceptually related terms
**Fix (v3.1)**: Added proactive terminology search — think about what concepts the source discusses, search vault, weave inline

## Pattern 7: Memorable Quotes Bullet Format (GPT-5.4 model limitation)
**Symptom**: GPT-5.4 uses `- "quote"` instead of `> "quote"` blockquote format
**Status**: Persists despite 4+ prompt iterations. Model-level preference. Per-source inline quotes use blockquote correctly.
**Workaround**: Accepted as cosmetic. Per-source sections have correct blockquote format.

## Quality Benchmarks
| Version | Score | Sources Found | Leakage | Wikilinks | Synthesis |
|---------|-------|---------------|---------|-----------|-----------|
| v1 (baseline) | 5.0/10 | 3/5 | N/A | 3 | Weak |
| v2 | ~6/10 | 11 (over-inclusive) | SEVERE | 10+ but invalid | Template |
| v3 | 8.4/10 | 2/2 (light day) | NONE | 5 (low density) | Opus-level |
| v3.1 | TBD | TBD | TBD | TBD | TBD |
| Target | 9.0+ | All real sources | NONE | 8-15 validated | Opus-level |

## Pattern 8: Hallucinated Source (v3.1, NEW)
**Symptom**: Per-source section written for a file that does not exist in the vault
**Example**: "The art of influence: Jessica Fain" — `obsidian read file="..."` failed in the vault
**Root cause**: Agent fabricated a source from general knowledge instead of vault files
**Fix**: Added mandatory `obsidian read file="..."` verification for every source before inclusion
**Severity**: CRITICAL — undermines trust in the entire roundup
