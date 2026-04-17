# agent-browser Patterns

## OAuth Sign-in (e.g. gws auth)

```bash
# 1. Start OAuth flow, capture URL
BROWSER=echo gws auth login > /tmp/oauth.txt 2>&1 &
GWS_PID=$!
sleep 3
OAUTH_URL=$(grep -o 'https://accounts.google.com[^ ]*' /tmp/oauth.txt)

# 2. Open in agent-browser (CDP-connected Chrome for Google)
agent-browser connect 9222
agent-browser --session-name gws-auth open "$OAUTH_URL"
sleep 3
agent-browser --session-name gws-auth snapshot

# 3. Fill email, click Next
agent-browser --session-name gws-auth fill '@eN' 'user@gmail.com'
agent-browser --session-name gws-auth click '@eM'

# 4. Handle password/2FA, then wait for callback
wait $GWS_PID                   # gws captures the redirect token
```

Key gotchas:
- Google blocks Playwright Chromium — always connect to real Chrome via `connect 9222`.
- Re-snapshot between each page (login → password → 2FA are separate pages).

## Blog Publishing (naver / tistory)

```bash
# Headed + named session is mandatory for login persistence
agent-browser --headed --session-name naver open "https://blog.naver.com/.../postwrite"
agent-browser --headed --session-name naver snapshot

# Fill title via ref
agent-browser --headed --session-name naver fill '@eN' "제목"

# Inject body through site API (SmartEditor)
agent-browser --headed --session-name naver eval "
  window.SmartEditor.setContent(\`$CONTENT\`);
"

# Publish
agent-browser --headed --session-name naver click '@eM'

# Verify (silent-failure guard)
sleep 2
POST_URL=$(agent-browser --headed --session-name naver eval "window.location.href")
echo "$POST_URL" | grep -q '/PostView' || { echo "publish did not navigate"; exit 1; }
```

Key gotchas:
- Always `eval` for SmartEditor/tinymce — `fill` cannot reach iframed editors.
- Always verify navigation after publish; Naver fails silently on some error paths.
- Never call `close` between steps — it kills the shared browser process.

## Session Recovery (cookie expiry)

```bash
# Trigger: "not logged in" state after a snapshot
agent-browser --headed --session-name <name> open <login-url>
# User completes login interactively
agent-browser --session-name <name> snapshot
# Confirm logged-in indicator (profile name, "logout" link, etc.)
```

## Screenshot-driven Debugging

When a skill fails silently, capture full-page screenshot before close:

```bash
agent-browser --session-name <name> screenshot --full "/tmp/<skill>-$(date +%s).png"
```
