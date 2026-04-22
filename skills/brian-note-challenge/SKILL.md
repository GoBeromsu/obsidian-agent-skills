---
name: brian-note-challenge
description: Fetch the daily Brian Note Challenge email via gws CLI and create a structured vault note using obsidian CLI. Use when the daily BNC email needs to be ingested into the vault as a note, when a past BNC note must be backfilled, or when the scheduled OpenClaw BNC flow stops creating the note/dashboard entry and needs troubleshooting.
---

# BNC (Brian Note Challenge)

## Overview

Fetch today's Brian Note Challenge email from Gmail via `gws` CLI, extract the challenge topic (Q1 Korean + English), and create a vault note using `obsidian` CLI. The note follows the Template structure (공명 / 연관 노트 / 본문) for the user to fill in.

Detailed process reference: `[[Brian Note Challenge Daily (BNC)]]`

## Vault Access

Use the `obsidian-cli` skill for all note creation, edit, search, and property mutation inside the Ataraxia vault. Do not shell out to raw `cat`/`sed` on vault paths. See the `obsidian-cli` SKILL.md for the command surface and required preconditions (Obsidian must be running).

## When to Use
- The daily BNC email has arrived and needs to be ingested into the vault
- A past BNC email was missed and needs retroactive ingestion
- The scheduled OpenClaw BNC run completed but no Ataraxia note or dashboard link appeared
- The deployed BNC runtime appears stale, drifted from SSOT, or is writing to the wrong vault path
- `gws` Gmail auth errors block the scheduled run
- Do NOT use for general email triage or non-BNC emails
- Do NOT use for manual note creation without an email source

### Prerequisites
- `gws` CLI installed and authenticated (`gws auth login`)
- Obsidian running (required for `obsidian` CLI)
- This directory is the SSOT for the BNC skill. Deployed OpenClaw/runtime copies are mirrors and must be synced from here.

## Process

### Step 1 — Determine Target Date

Determine target date `D` in KST (format: `YYYY-MM-DD`). Default: today.

### Step 2 — Gmail Fetch & Parse

1. Search for the newest matching email:
   ```
   gws gmail users messages list --params '{"userId":"me","q":"newer_than:2d from:brian.brain.trinity@gmail.com (\"질문입니다\" OR \"1MNC\" OR \"Note Challenge\" OR \"Brian Note Challenge\")","maxResults":5}'
   ```
2. Pick the newest message id.
3. Fetch the full message:
   ```
   gws gmail users messages get --params '{"userId":"me","id":"<MESSAGE_ID>","format":"full"}'
   ```
4. Decode the first `text/plain` MIME part from `payload.parts` (base64url).
5. Parse the plain text body:
   - Find line `1.` (or `1`).
   - Q1 Korean = first non-empty line after that containing at least one Hangul character.
   - Q1 English = first following line or prefix containing ASCII letters, even if the email format changed and trailing Korean text appears after the English sentence on the same line.
   - Do NOT require `?` in either line. Subject/body format can change.
6. If no matching email found (query returns 0 results): stop and report "no BNC email found for date `D`".
7. If parsing fails (no Q1 Korean topic found): stop and report the error. Do NOT guess.

### Step 3 — Sanitize Topic for Filename

Remove `[?!:*"<>|/\\]`, collapse multiple spaces, trim leading/trailing spaces, limit to 100 characters. Result = `T`.

### Step 4 — Create Note

Target path: `15. Work/02 Area/Brian Note challenge/${D} ${T}.md`

1. **Duplicate check**: glob `${D} *.md` in `15. Work/02 Area/Brian Note challenge/`. If a same-date note exists, skip creation.
2. **Create note** via obsidian CLI:
   ```
   obsidian create path="15. Work/02 Area/Brian Note challenge/${D} ${T}.md" vault="Ataraxia" content="..."
   ```
3. **Note content**:
   ```markdown
   ---
   tags:
     - brian/notechallenge
   aliases: []
   date_created: ${D}
   type: article
   project: "[[Brian Note challenge]]"
   ---
   > [!note]
   > 오늘의 주제: ${Q1_KOREAN}
   > ${Q1_ENGLISH}

   ## 1. 공명
   > 의식의 흐름에 따라 마음 속의 울림을 먼저 적습니다.

   ## 2. 연관 노트

   ## 3. 본문
   ```
4. If `obsidian create` fails (e.g., Obsidian not running): log the error and stop. Do not attempt Dashboard update.

### Step 5 — Update Dashboard

Under `## Routine` in `10. Time/06 Dashboard/${D} Dashboard.md`, ensure exactly one bullet:
```
- [[${D} ${T}]]
```

If a legacy link (e.g. `[[YYYY-MM-DD Brian note challenge]]`) or another same-date Brian link already exists, replace it. Never create duplicates.

## Troubleshooting

### Case 1 — Scheduled OpenClaw run fires, but no note appears in Ataraxia
1. Verify the canonical target paths are still:
   - `15. Work/02 Area/Brian Note challenge/`
   - `10. Time/06 Dashboard/`
2. Verify the deployed runtime script is synced from this SSOT skill directory, not an older remote copy.
3. Re-run the skill manually for today before changing the scheduler.
4. If the manual run works but cron does not, treat the runtime environment as the problem, not the content template.

### Case 2 — Deployed runtime drifted from SSOT
1. Compare the remote/deployed `SKILL.md` and runtime script against this directory.
2. If they differ, overwrite the deployed copy from SSOT instead of hot-editing the deployed mirror.
3. Re-verify the runtime writes to the canonical Ataraxia paths after sync.

### Case 3 — `gws` Gmail auth fails
1. Treat `401`, `invalid_grant`, `Failed to get token`, or `Access denied` as auth failures first.
2. Re-run `gws auth login` on the actual runtime machine/environment used by the scheduled job.
3. Use the existing browser profile for re-auth if available, but keep the skill/report generic.
4. Never paste or store tokens, login/session values, IP addresses, or personal identifiers in the skill, logs, summaries, or troubleshooting notes.
5. Report the failure generically, for example: `gws Gmail auth failed on runtime machine; re-auth required`.

### Case 4 — Email format changed and parsing breaks
1. Re-check the raw `text/plain` body before changing the note template.
2. Do not assume Q1 English is on its own clean line or that it ends with `?`.
3. Prefer resilient extraction rules over one-off hardcoded fixes for a single day.

### Case 5 — Note exists but dashboard link is missing
1. Do not recreate the note.
2. Update only the `## Routine` block in the day dashboard.
3. Ensure exactly one same-day BNC bullet remains after the fix.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "Extraction is simple, skip the parsing logic." | Email format varies between sends. Robust heuristic parsing prevents silent data corruption. |
| "Duplicate check is overkill for a daily skill." | Re-runs and retries happen. The check prevents double-creation. |
| "Dashboard update can wait." | Routine tracking breaks if the wikilink is missing from the daily dashboard. |
| "I can hardcode the email query." | The sender uses varying subject lines. The OR-based query handles all known variants. |
| "The remote copy is probably close enough; I'll patch it directly." | Deployed copies drift. Fix SSOT first, then sync mirrors from this directory. |
| "The auth error log is useful as-is, I'll just paste everything." | Tokens, login/session details, IPs, and other personal/runtime identifiers must never be copied into the skill or reports. |

## Red Flags
- Note created without running a duplicate check first
- Hardcoded email queries missing the standard OR filter terms
- Missing Q1 English line in callout (only Korean topic shown)
- Wrong tag casing: `brian/noteChallenge` instead of `brian/notechallenge`
- Frontmatter uses array notation `[brian/notechallenge]` instead of indented YAML list
- use `date_created:` only
- Editing a deployed OpenClaw/runtime copy without updating SSOT first
- Troubleshooting notes or logs contain tokens, login/session data, IP addresses, or personal identifiers

## Verification

	After completing the process, confirm:
- [ ] `gws` query returned a matching email
- [ ] Q1 Korean + Q1 English extracted correctly from email body
- [ ] Duplicate check ran before note creation
- [ ] Note exists at `15. Work/02 Area/Brian Note challenge/${D} ${T}.md`
- [ ] Frontmatter has `brian/notechallenge` (lowercase), `date_created:`, `type: article`, `project:`
- [ ] Note content has callout (Korean + English) → 공명 → 연관 노트 → 본문
- [ ] Dashboard `## Routine` updated with `[[${D} ${T}]]` wikilink
- [ ] Any deployed/runtime copy was synced from this SSOT skill if troubleshooting required a remote fix
- [ ] Troubleshooting output contains no tokens, login/session information, IP addresses, or personal identifiers
