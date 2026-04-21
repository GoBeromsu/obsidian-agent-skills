---
name: reflect-dankoe
description: Use when you need to run a structured daily reflection protocol inspired by Dan Koe, especially for guided question flow, one-question-at-a-time reflection, and recording answers into a daily note.
---

# reflect-dankoe

## Overview
Use this skill to run a structured reflection routine based on a question protocol. The public-safe version preserves the guided reflection flow while removing private daily-note assumptions and personal naming conventions.

## When to Use
- Use when the user explicitly wants to do a guided reflection run
- Use when a one-question-at-a-time reflection protocol is needed
- Use when reflection answers should be recorded into a daily note or journal entry
- Do not use for open-ended journaling when the user does not want a guided protocol

## Process
1. **Choose the reflection context**
	- Decide whether the reflection is for morning setup, mid-day interruption, or evening synthesis.
	- Answers are stored in the daily note at `10. Time/01 Daily Notes/YYYY-MM-DD.md`.

2. **Ask one question at a time**
	- Present a single reflection question.
	- Wait for the answer before moving to the next prompt.

3. **Record answers structurally**
	- Append each answer to today’s daily note using:
	  `obsidian vault=”Ataraxia” append path=”10. Time/01 Daily Notes/YYYY-MM-DD.md” content=”...”`
	- Keep answers in order with a `## Reflection` section header if not already present.
	- This reflection is part of the daily routine connected to the CMDS framework at `20. CMDS/`.

4. **Close with synthesis**
	- Summarize patterns, intentions, or next actions only after the answers are collected.
	- Keep the synthesis faithful to what the user actually said.

## Common Rationalizations
| Rationalization | Reality |
|---|---|
| “I can dump all questions at once.” | Guided reflection works better one question at a time. |
| “The storage location does not matter.” | Reflection notes live at `10. Time/01 Daily Notes/YYYY-MM-DD.md` — a consistent, findable location. |
| “I can summarize aggressively at the end.” | The synthesis should preserve the user’s actual reflection rather than overwrite it. |

## Red Flags
- Multiple reflection questions are batched together unnecessarily
- Answers are stored somewhere other than `10. Time/01 Daily Notes/YYYY-MM-DD.md`
- The final synthesis introduces ideas the user did not express

## Verification
After completing the skill’s process, confirm:
- [ ] Questions were asked one at a time
- [ ] Answers were appended to `10. Time/01 Daily Notes/YYYY-MM-DD.md` in order
- [ ] A `## Reflection` section header frames the recorded answers
- [ ] Final synthesis remains faithful to the user’s answers
