---
name: agent-browser
description: Drive Chrome via CDP for browser automation using the snapshot → ref → act loop. Use when the user says "agent-browser", "브라우저 자동화", "headed browser", or when another skill (naver, tistory, gws OAuth) needs browser interaction. Covers install, session management, and the ephemeral-ref workflow.
---

# agent-browser

## Overview

Fast Rust CLI controlling Chrome via Chrome DevTools Protocol. The canonical loop is **snapshot → ref → act → re-snapshot**: every page change invalidates refs, so never chain actions without a fresh snapshot. Sessions persist cookies across invocations; `close` is destructive and kills shared browser processes.

## When to Use

- Use when another skill (naver, tistory, Gmail/GWS OAuth) needs to drive a browser.
- Use for headed flows where Google/Naver blocks automated Chromium — connect to a real Chrome via CDP.
- Use for content injection when selectors fail (SmartEditor, tinymce) — `eval` is more reliable.
- Do NOT use for simple HTTP requests — use `curl` or `gh api`.
- Do NOT use for scraping public pages that don't need a session — prefer `defuddle`.

## Install

```bash
npm install -g agent-browser
agent-browser install          # downloads Chrome for Testing
agent-browser --version        # verify
```

Update with `agent-browser upgrade`.

## Core Workflow: Snapshot → Ref → Act

```bash
agent-browser snapshot                      # tree with @e1, @e2, ...
agent-browser click '@e5'                   # act by ref
agent-browser fill '@e3' 'hello@test.com'   # clear + fill
agent-browser snapshot                      # refs invalidated by DOM change — re-snapshot
```

Refs (`@eN`) are **ephemeral**. Any navigation, DOM mutation, or tab switch invalidates them.

## Session Management

Named sessions persist cookies + storage; each is isolated at `~/.agent-browser/sessions/<name>/`.

```bash
agent-browser --session-name naver open https://blog.naver.com
agent-browser --headed --session-name tistory open https://tistory.com    # visible for manual login
```

Login recovery when cookies expire:

```bash
agent-browser --headed --session-name <name> open <login-url>
# user completes login in the visible window
agent-browser --session-name <name> snapshot                               # verify logged in
```

`close` terminates the shared browser process — all sessions in the same Chrome die. Prefer leaving sessions open; use `close --all` only when certain.

## CDP Connection (for Google OAuth)

Google blocks Playwright-branded Chromium. Connect to a real Chrome instance instead:

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --remote-debugging-port=9222 --no-first-run \
  --user-data-dir="$HOME/.chrome-debug" "about:blank" &>/dev/null &

agent-browser connect 9222
```

After connecting, all commands drive the real Chrome window and bypass automation detection.

## References

- Full command reference: `references/COMMANDS.md`
- OAuth sign-in and blog publishing patterns: `references/PATTERNS.md`

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll chain click + fill without re-snapshotting, saves a step." | Any DOM change invalidates refs. The second action targets a stale element and silently misfires. Re-snapshot after every action that mutates the page. |
| "close is fine, I'll just reopen." | Close kills the shared browser. Other named sessions die with it and must re-login. Use only when certain no other session is active. |
| "Playwright Chromium is fine for Google login." | Google detects it and blocks. Use CDP to connect to real Chrome. |
| "Naver blog publish succeeded — I saw no error." | Naver fails silently on some errors. Verify the URL changed or a success indicator appeared before reporting success. |
| "`click` is safer than `eval`." | For SmartEditor/tinymce content injection, `eval` is the only reliable path. `click`/`fill` misses iframed editors. |

## Red Flags

- Chaining two `@eN` actions without a snapshot between them
- Running `close` without confirming no other named session is in flight
- Reporting publish success without an explicit URL/text check
- Using `click`/`fill` inside SmartEditor or tinymce iframes instead of `eval`
- Using Playwright Chromium (no `connect`) for a Google sign-in flow

## Verification

After completing a browser-driven task, confirm:

- [ ] Every action sequence has a fresh `snapshot` preceding it
- [ ] For publish flows: explicit post-publish URL check or success-text assertion is present
- [ ] No `close` was called while another skill's session was active
- [ ] Screenshot (`screenshot --full`) captured at the final state when the task requires a visible artifact
- [ ] Session cookies still valid at end of task (or a recovery note left for next run)
