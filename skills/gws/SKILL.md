---
name: gws
description: Use the gws CLI to interact with Google Workspace services — Drive, Calendar, Gmail, Sheets, Docs, Forms, and Chat. Triggers when the user wants to manage Drive files, access Calendar events, send email, work with Sheets/Docs, handle Forms responses, or any Google Workspace API task. Also triggers for gws authentication setup, login errors, headless auth export, OAuth scope issues, service account configuration, or any "gws" command question.
---

# gws

## Overview

`gws` is a universal CLI for Google Workspace that dynamically builds commands from Google's Discovery API — no static command lists. Every response is structured JSON, making it scriptable and agent-friendly. Covers Drive, Calendar, Gmail, Sheets, Docs, Forms, Chat, and more.

Install: `npm install -g @googleworkspace/cli` or `brew install googleworkspace-cli`

## Authentication — Start Here

Authentication must be set up before any commands work. Check status first:

```bash
gws drive files list --params '{"pageSize": 1}'
echo $?   # 2 = auth error, 0 = OK
```

### Which Flow to Use

| Situation | Command |
|---|---|
| First-time setup, `gcloud` installed | `gws auth setup` |
| First-time setup, no `gcloud` | Manual OAuth setup (see below) |
| Adding new scopes | `gws auth login -s drive,calendar,gmail` |
| Headless/CI environment | Export flow (see below) |
| Service account key available | `GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE=/path/to/key.json` |

### First-time: With gcloud

```bash
gws auth setup     # one-time: creates GCP project, enables APIs, logs in
gws auth login     # subsequent logins / scope changes
```

### First-time: Manual OAuth (no gcloud)

1. GCP Console → your project → APIs & Services → Credentials
2. Create OAuth 2.0 Client ID → type: **Desktop app**
3. Download JSON → save to `~/.config/gws/client_secret.json`
4. OAuth consent screen → **Test users → Add users** → add your Google account email
5. Run: `gws auth login -s drive,calendar,gmail`

> Unverified apps (testing mode) are limited to ~25 scopes. Do NOT use the `recommended` scope preset — it includes 85+ scopes and will fail. Always specify individual services.

### Headless / CI Export

```bash
# On a browser-capable machine:
gws auth export --unmasked > credentials.json

# On the headless machine:
export GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE=/path/to/credentials.json
gws drive files list   # just works
```

### Common Auth Errors

| Error | Fix |
|---|---|
| "Access blocked" | Add your account as a test user in the OAuth consent screen |
| "Google hasn't verified this app" | Click Advanced → Go to app (unsafe) — safe for personal use |
| Too many scopes / consent error | Use `-s drive,calendar,gmail` instead of `recommended` |
| `redirect_uri_mismatch` | Delete current OAuth client, recreate as **Desktop app** type |
| `accessNotConfigured` (403) | Enable the API in GCP Console at the `enable_url` in the error JSON |

### Token Expiry — `invalid_grant` Recovery

gws tokens expire periodically. When `invalid_grant` or `token_valid: false` appears, re-authenticate:

```bash
# Re-run login with the scopes you originally used
gws auth login -s drive,calendar,gmail

# Verify recovery
gws drive files list --params '{"pageSize": 1}'
echo $?   # must be 0
```

If the environment is headless or browser login isn't possible, use agent-browser to automate the OAuth consent flow (see TOOLS.md for your environment-specific setup).

---

## Drive

```bash
# List recent files
gws drive files list --params '{"pageSize": 10}'

# Search files by name
gws drive files list --params '{"q": "name contains \"report\"", "pageSize": 20}'

# Upload a file (helper)
gws drive +upload ./report.pdf --name "Q1 Report"

# Upload with full metadata
gws drive files create --json '{"name": "report.pdf"}' --upload ./report.pdf

# Stream all files across pages
gws drive files list --params '{"pageSize": 100}' --page-all | jq -r '.files[].name'

# Get file metadata
gws drive files get --params '{"fileId": "FILE_ID"}'

# Inspect available parameters for any method
gws schema drive.files.list
```

---

## Calendar

```bash
# Today's agenda (uses Google account timezone automatically)
gws calendar +agenda

# Agenda in a specific timezone
gws calendar +agenda --today --timezone Asia/Seoul

# Create an event (helper)
gws calendar +insert \
  --summary "Team Meeting" \
  --start "2026-04-16T10:00:00+09:00" \
  --end "2026-04-16T11:00:00+09:00"

# List upcoming events
gws calendar events list \
  --params '{"calendarId": "primary", "maxResults": 10, "orderBy": "startTime", "singleEvents": true, "timeMin": "2026-04-15T00:00:00Z"}'

# Create event with full control
gws calendar events insert \
  --params '{"calendarId": "primary"}' \
  --json '{"summary": "Meeting", "start": {"dateTime": "2026-04-16T10:00:00+09:00"}, "end": {"dateTime": "2026-04-16T11:00:00+09:00"}}'

# List all calendars
gws calendar calendarList list
```

---

## Gmail

```bash
# Unread inbox summary
gws gmail +triage

# Send email
gws gmail +send --to recipient@example.com --subject "Subject" --body "Message"

# Reply to a message (handles threading automatically)
gws gmail +reply --message-id MESSAGE_ID --body "Reply text"

# Watch for new emails (streams NDJSON)
gws gmail +watch

# List unread messages
gws gmail users messages list --params '{"userId": "me", "maxResults": 10, "q": "is:unread"}'
```

---

## Sheets

> Always use **single quotes** around JSON containing `!` (Sheets ranges). Bash treats `!` in double quotes as history expansion.

```bash
# Read cells
gws sheets spreadsheets values get \
  --params '{"spreadsheetId": "SPREADSHEET_ID", "range": "Sheet1!A1:C10"}'

# Append rows
gws sheets spreadsheets values append \
  --params '{"spreadsheetId": "ID", "range": "Sheet1!A1", "valueInputOption": "USER_ENTERED"}' \
  --json '{"values": [["Name", "Score"], ["Alice", 95]]}'

# Create a spreadsheet
gws sheets spreadsheets create --json '{"properties": {"title": "My Sheet"}}'

# Quick append (helper)
gws sheets +append --spreadsheet SPREADSHEET_ID --values "Alice,95"
```

---

## Forms

Google Forms API is available via Discovery:

```bash
# List forms
gws forms forms list

# Get form details
gws forms forms get --params '{"formId": "FORM_ID"}'

# Get form responses
gws forms forms responses list --params '{"formId": "FORM_ID"}'

# Inspect available schema
gws schema forms.forms.get
```

> If you get `accessNotConfigured` (exit 1), enable the Google Forms API at the `enable_url` printed in the error output, wait ~10 seconds, then retry.

---

## Utility Patterns

### Dry Run (preview request without executing)
```bash
gws chat spaces messages create \
  --params '{"parent": "spaces/xyz"}' \
  --json '{"text": "Deploy complete."}' \
  --dry-run
```

### Pagination
```bash
gws drive files list --params '{"pageSize": 100}' --page-all        # all pages, NDJSON
gws drive files list --params '{"pageSize": 100}' --page-limit 5    # max 5 pages
```

### Schema Inspection (when unsure of parameters)
```bash
gws schema drive.files.list
gws schema calendar.events.insert
gws <service> --help    # list all Discovery methods + helper commands for a service
```

### Exit Codes (for scripting)
| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | API error (4xx/5xx from Google) |
| 2 | Auth error — credentials missing or expired |
| 3 | Validation error — bad args or unknown service |
| 4 | Discovery error |
| 5 | Internal error |

---

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll use the `recommended` scope preset." | Unverified apps cap at ~25 scopes — `recommended` (85+) will fail. Always pick specific scopes. |
| "I don't need to add myself as a test user." | This is the #1 cause of "Access blocked." No test user = no login. |
| "I'll wrap the Sheets range in double quotes." | Bash history expansion breaks ranges containing `!`. Always use single quotes around JSON. |
| "This command probably doesn't exist in gws." | gws builds from Discovery dynamically. Try `gws <service> --help` first before falling back to curl. |
| "I'll put credentials in the script directly." | Use `GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE` env var — never hardcode credential paths in shared scripts. |

## Red Flags

- Using `recommended` scope preset with an unverified OAuth app
- Double-quoting Sheets ranges that contain `!`
- Not checking exit code when scripting gws commands
- Running `gws auth setup` without `gcloud` installed
- Skipping test user registration in OAuth consent screen

## Verification

- [ ] `gws drive files list --params '{"pageSize": 1}'` returns JSON with exit code 0
- [ ] Credentials stored via env var, not hardcoded in scripts
- [ ] For headless: `GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE` points to a valid exported file
- [ ] Sheets JSON is single-quoted when ranges contain `!`
- [ ] New APIs (Forms, etc.) enabled in GCP Console if `accessNotConfigured` appeared
