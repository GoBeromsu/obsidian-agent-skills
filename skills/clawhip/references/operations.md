# clawhip Operations Reference

Read this file when you need architecture context, troubleshooting tips, or daemon lifecycle details beyond the core workflow in SKILL.md.

## Architecture Context

```
[Discord (사용자)] → [OpenClaw maestro] → [clawhip deliver] → [OMX (tmux)]
                                                                    ↓
                                              [clawhip daemon 감시] → [Discord 알림]
```

| Component        | Role                         | Port  | Process Manager         |
| ---------------- | ---------------------------- | ----- | ----------------------- |
| clawhip daemon   | Event routing + notification | 25294 | nohup (launchd pending) |
| OpenClaw Gateway | Messenger → agent routing    | 18789 | launchd                 |
| OMX              | Code execution in tmux       | —     | tmux session            |

clawhip and OpenClaw use **separate Discord bots**. This separation prevents high-frequency notifications (commits, keywords, stale alerts) from polluting the conversational bot's context.

## Troubleshooting (삽질 기록)

### TOML config pitfalls
- `[[monitors.git]]` is wrong — clawhip uses event-based git monitoring, not polling. This TOML key causes silent parse errors.
- Route `event` fields use dot notation with glob: `github.*`, `tmux.*`, `agent.*`, `session.*`.
- Legacy `[discord]` config is still accepted but prefer `[providers.discord]`.

### Channel binding silent failure
When adding a new channel for routing, the channel must also be registered in the guild channel allowlist on the Discord bot side. Missing this causes silent delivery failure — the daemon reports success but no message appears.

### Daemon lifecycle
- Currently runs via `nohup clawhip &`. Survives terminal close but not reboot.
- Pending migration: register as launchd service for auto-start on boot.
- After m1-pro reboot, manually restart: `nohup clawhip > /tmp/clawhip.log 2>&1 &`

### Session naming
- Session names are operator labels, not routing authority. Route filtering should use project metadata (`filter = { repo = "..." }`) not session names.
- Broad prefix monitors like `clawhip*` overlap with launcher-registered watches and create stale/keyword noise.

### deliver safety
- `clawhip deliver` refuses arbitrary shells — it requires repo-local prompt-submit-aware hook setup.
- Install hooks first: `clawhip hooks install --all --scope project`
- deliver retries Enter keypresses (bounded by `--max-enters`) until `.clawhip/state/prompt-submit.json` changes.
