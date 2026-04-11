---
name: clawhip
description: Manage clawhip daemon operations on m1-pro — stale watch cleanup, tmux session monitoring, deliver prompt injection, and routing configuration. Use when clawhip stale notifications fire on idle sessions, when managing tmux watches, when injecting prompts via deliver, or when updating event routing rules. Depends on tailscale skill for SSH connectivity.
---

# clawhip

## Overview
Operate the clawhip event-routing daemon running on m1-pro. This skill captures personal operational context (error patterns, workarounds, architecture decisions) that generic docs do not cover. For standard CLI reference and setup instructions, query NotebookLM MCP with the clawhip notebook instead.

clawhip's role in the stack: it is the "무대 매니저" (stage manager) — it watches tmux sessions, git/github events, and agent lifecycle, then routes notifications to Discord. It does not execute code or make decisions; it observes and reports.

## When to Use
- Stale notifications firing on idle tmux sessions (e.g., `maestro-work pane 0.0 stale for 10m`)
- Need to list, stop, or restart tmux watches on m1-pro
- Injecting prompts into an OMX tmux session via `clawhip deliver`
- Adding or modifying event routing rules in `~/.clawhip/config.toml`
- Checking daemon health after m1-pro reboot or network interruption
- NOT for clawhip installation or initial setup (use NotebookLM MCP docs)
- NOT for OpenClaw agent management (use `openclaw` skill)
- NOT for OMX skill configuration (separate domain)

## Process

### 1. Establish SSH connectivity
Follow the `tailscale` skill to verify m1-pro reachability, then connect:
```bash
tailscale ping m1-pro
ssh m1-pro
```
All subsequent commands run on m1-pro unless stated otherwise.

### 2. Check daemon health
```bash
clawhip status
```
If the daemon is not running, check the process manager. clawhip currently runs via nohup (launchd migration is pending — see Operational Notes).

### 3. Diagnose the situation

**For stale notifications on idle sessions:**
```bash
# List all active tmux watches with source and registration timestamp
clawhip tmux list
```
Identify which watch is firing stale alerts. The output shows session name, pane, monitoring config (keywords, stale-minutes), and registration time.

**For prompt injection:**
```bash
clawhip deliver --session <session-name> \
  --prompt "<prompt-text>" \
  --max-enters 4
```
`deliver` validates repo-local prompt-submit hook setup and confirms the target pane is an active Codex/Claude/OMX session before injecting.

**For routing issues:**
Check the config file directly:
```bash
cat ~/.clawhip/config.toml
```

### 4. Resolve — Stale Watch Management

**Stop monitoring a specific session** (when no work is active):
```bash
# Option A: Kill the tmux watch registration
# The exact command depends on how the watch was registered.
# If registered via `clawhip tmux watch`, stopping the watch process ends monitoring.
# If registered via `clawhip tmux new`, the session itself carries the watch config.

# Check what's registered first
clawhip tmux list

# To stop stale alerts without killing the session,
# re-register the watch with stale monitoring disabled:
clawhip tmux watch -s <session-name> \
  --keywords '<keyword-list>' \
  --stale-minutes 0
```

**Restart monitoring with adjusted thresholds:**
```bash
clawhip tmux watch -s <session-name> \
  --mention '<@discord-user-id>' \
  --keywords 'error,PR created,complete,FAILED' \
  --stale-minutes <minutes> \
  --format alert
```

**Create a new monitored session** (when starting fresh work):
```bash
clawhip tmux new -s <session-name> \
  --channel <discord-channel-id> \
  --mention '<@discord-user-id>' \
  --keywords 'error,PR created,complete,FAILED' \
  --stale-minutes 10 \
  -- '<shell-command>'
```

### 5. Verify resolution
```bash
# Confirm the watch state matches intent
clawhip tmux list

# Optionally test a notification
clawhip send --channel <channel-id> --message "test: clawhip watch reconfigured"
```

## Reference

For architecture diagrams, troubleshooting (삽질 기록), daemon lifecycle, and deliver safety details, see [references/operations.md](references/operations.md).

## Common Rationalizations
| Rationalization | Reality |
|---|---|
| "The stale alert means something is wrong." | Stale just means no output for N minutes. Idle sessions trigger it legitimately. Reconfigure or disable the watch. |
| "I'll just kill the tmux session to stop alerts." | Killing the session loses the OMX runtime. Disable or reconfigure the watch instead. |
| "Channel ID is not sensitive." | Discord channel IDs combined with bot tokens enable message injection. Use placeholders. |
| "I can edit config.toml from the local machine." | config.toml lives on m1-pro. SSH in first. |

## Red Flags
- Tailscale IP addresses (100.x.x.x), Discord tokens, or channel IDs appear in output
- SSH attempted before `tailscale ping m1-pro` confirms reachability
- tmux session killed to resolve stale alerts instead of reconfiguring the watch
- Config changes attempted on local machine instead of m1-pro
- `[[monitors.git]]` TOML syntax used in config (event-based, not polling)

## Verification
After completing the workflow, confirm:
- [ ] `tailscale ping m1-pro` confirmed reachability before SSH
- [ ] `clawhip status` shows daemon running on m1-pro
- [ ] `clawhip tmux list` reflects intended watch state (enabled/disabled/reconfigured)
- [ ] No Tailscale IPs, Discord tokens, or channel IDs in output
- [ ] If stale was the issue: alerts have stopped for the target session
- [ ] If deliver was used: target OMX session received the prompt
