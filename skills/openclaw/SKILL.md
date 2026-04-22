---
name: openclaw
description: Manage OpenClaw agent lifecycle on m1-pro — add/remove/modify agents, bind Discord channels, configure cron/heartbeat, check gateway health, and clean up deprecated agents (e.g., GSoC). Use when managing OpenClaw agents, cron jobs, gateway status, channel bindings, or agent cleanup tasks. Depends on tailscale skill for SSH connectivity.
---

# openclaw

## Overview
Operate the OpenClaw multi-agent gateway running on m1-pro. OpenClaw runs in parallel with the Hermes Docker runtime; both are live on m1-pro and have distinct workspaces. Use this skill when the task targets the OpenClaw gateway specifically; use the Hermes skill family when the task targets the Hermes runtime. OpenClaw is the "지휘자" (conductor) — it receives messages from Discord/Telegram/Slack, routes them to the appropriate AI agent, and returns responses. This skill captures personal operational context that generic docs do not cover. For standard CLI reference and setup instructions, query NotebookLM MCP with the OpenClaw documentation.

Vault reference: `Ataraxia/50. AI/04 Skills/Obsidian/openclaw/` is the live vault source for this skill package and its supporting references.

## When to Use
- Adding, removing, or modifying agents (model change, identity update, skill assignment)
- Changing agent persona, speech style, or tone (SOUL.md)
- Binding or unbinding Discord channels to agents
- Managing cron jobs and heartbeat configurations
- Checking gateway health after reboot or network interruption
- Cleaning up deprecated agents and their resources (e.g., GSoC-related agents)
- Resetting a Discord session to pick up bootstrap changes (SOUL.md, IDENTITY.md)
- Updating agent skills in `~/.openclaw/skills/`
- Configuring maestro's OMX dispatch rules in AGENTS.md
- Verifying the relay chain: Discord → maestro → clawhip deliver → OMX
- NOT for clawhip daemon operations (use `clawhip` skill)
- NOT for OMX tmux session management (separate domain)
- NOT for initial OpenClaw installation (use NotebookLM MCP docs)

## Process

### 1. Establish SSH connectivity
Follow the `tailscale` skill to verify m1-pro reachability, then connect:
```bash
tailscale ping m1-pro
ssh m1-pro
```
All subsequent commands run on m1-pro unless stated otherwise.

### 2. Check gateway health
```bash
# Verify the gateway process is running (managed by launchd)
launchctl list | grep openclaw

# Test gateway responsiveness
curl -s http://127.0.0.1:18789/health
```
If the gateway is down, launchd should auto-restart it. If it remains down:
```bash
launchctl kickstart -k system/openclaw  # or the correct service label
```

### 3. Agent lifecycle operations

**List current agents:**
```bash
openclaw agents list
```

**Add a new agent:**
```bash
openclaw agents add \
  --name <agent-name> \
  --model <model-id>
```
After adding, create bootstrap files in the workspace root:
- `SOUL.md` — speech style, tone, and personality ("where your agent's voice lives"). Injected every turn.
- `IDENTITY.md` — name, emoji, avatar (agent metadata)
- `AGENTS.md` — operational rules
- `TOOLS.md` — local settings (SSH hosts, API keys)
- `USER.md` — user preferences and context

**Remove an agent:**
```bash
openclaw agents delete --name <agent-name>
```
Also clean up:
- Remove channel bindings (`openclaw agents unbind`)
- Remove cron entries referencing the agent
- Remove agent directory in `~/.openclaw/agents/`
- Update vault workspace notes if they reference the agent

**Modify agent model:**
```bash
openclaw agents update --name <agent-name> --model <new-model-id>
```

### 4. Channel binding

**Bind a Discord channel to an agent:**
```bash
openclaw agents bind \
  --agent <agent-name> \
  --channel <discord-channel-id>
```

**Unbind:**
```bash
openclaw agents unbind \
  --agent <agent-name> \
  --channel <discord-channel-id>
```

After binding, verify the channel is also in the guild channel allowlist — missing this causes the gateway to receive messages but the agent never responds (silent failure).

### 5. Cron and heartbeat management

**Heartbeat** (built-in, conversational timing):
- Configured per-agent in the agent config
- Rotates through checks: email, calendar, mentions, weather
- State tracked in `memory/heartbeat-state.json`
- Override interval: `agents.list[].heartbeat.every`

**Cron** (exact timing, one-shot):
- System cron for scheduled tasks
- Obsidian CLI paths in cron scripts require explicit PATH export:
```bash
export PATH="/opt/homebrew/bin:$PATH"
```
- List current cron entries:
```bash
crontab -l
```
- Edit cron:
```bash
crontab -e
```

### 6. Skill management

Skills live in `~/.openclaw/skills/` on m1-pro:
```bash
ls ~/.openclaw/skills/
```

To add a skill, copy the SKILL.md (and supporting files) into a named subdirectory. To remove, delete the directory. After changes, the agent picks up skills on next session start — no gateway restart needed.

### 7. Agent persona and speech style changes

Bootstrap files (SOUL.md, etc.) are injected **every turn** (`contextInjection: "always"` by default). However, existing Discord sessions cache the previous bootstrap, so you must delete the transcript and start a new session for changes to take effect.

**Important**: Bootstrap files are loaded from the **workspace directory** (not agentDir). The `agents.list[].workspace` field in `openclaw.json` determines the loading path.

**Update speech style or personality:**
```bash
# Edit SOUL.md (located at workspace root)
vi <workspace-path>/SOUL.md
```

**Update metadata (name / emoji / avatar):**
```bash
vi <workspace-path>/IDENTITY.md
openclaw agents set-identity --agent <name> --from-identity
```

**Apply changes — Gateway restart + session reset:**
The gateway caches bootstrap files in memory, so a file edit alone is not enough. You must restart the gateway after any bootstrap file change. A session reset alone is insufficient.
```bash
# 1. Restart the gateway (required)
launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway
sleep 5
curl -s http://127.0.0.1:18789/health   # confirm healthy

# 2. Identify the current session ID
openclaw sessions --agent <name> --json

# 3. Back up and delete the transcript
cp ~/.openclaw/agents/<name>/sessions/<session-id>.jsonl /tmp/<backup-name>.jsonl
rm ~/.openclaw/agents/<name>/sessions/<session-id>.jsonl

# 4. Clean up sessions.json
openclaw sessions cleanup --agent <name> --fix-missing --enforce
```
The next Discord message will start a fresh session and inject the new SOUL.md.

**Test from CLI:**
```bash
# Force a new session with a fresh session-id
openclaw agent --agent <name> --session-id test-$(date +%s) --message '테스트 메시지'
```

### 8. Maestro OMX dispatch (지능형 릴레이)

Maestro is an "intelligent relay" — it receives natural language from Discord, decides which OMX skill to use, and dispatches via clawhip deliver. Users never call OMX commands directly.

**Dispatch chain:**
```
Discord → OpenClaw maestro → exec tool → clawhip deliver --session maestro-work --prompt '$skill "..."' → tmux send-keys → OMX
```

**AGENTS.md is the SSOT** for dispatch rules. Key rules to include:
- Session name fixed to `maestro-work` (prevent maestro from inventing session names)
- `omx --madmax --high` mandatory (headless MCP approval + max reasoning)
- Skill selection table: when to use `$ralph` vs `$deep-interview` vs `$ralplan` vs `$team`
- Forbidden patterns: `$executor` and `$architect` are NOT standalone skills

**After modifying AGENTS.md:**
```bash
# 1. Gateway restart (picks up new workspace files)
launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway
sleep 5 && curl -s http://127.0.0.1:18789/health

# 2. Clear existing sessions (forces fresh context with new AGENTS.md)
rm ~/.openclaw/agents/<agent-name>/sessions/*.jsonl
openclaw sessions cleanup --agent <agent-name> --fix-missing --enforce
```

**BOOTSTRAP.md vs AGENTS.md:**
- BOOTSTRAP.md = one-time (deleted after first run). Do NOT put operational rules here.
- AGENTS.md = loaded every session. All persistent rules go here.

### 9. Agent cleanup workflow (e.g., GSoC removal)

When deprecating an agent or project-specific resources:

1. **Identify what to remove:**
```bash
openclaw agents list                    # Find the agent
crontab -l | grep <project-keyword>     # Find related cron entries
ls ~/.openclaw/agents/<agent-id>/       # Check agent directory
```

2. **Unbind channels first** (prevents dangling routes):
```bash
openclaw agents unbind --agent <agent-name> --channel <channel-id>
```

3. **Remove cron entries:**
```bash
crontab -l > /tmp/crontab-backup.txt    # Backup first
crontab -e                               # Remove relevant lines
```

4. **Delete the agent:**
```bash
openclaw agents delete --name <agent-name>
```

5. **Clean up filesystem:**
```bash
# Agent directory
rm -rf ~/.openclaw/agents/<agent-id>/

# Any project-specific skills
rm -rf ~/.openclaw/skills/<project-skill>/
```

6. **Update vault references:**
- Check `Ataraxia/50. AI/04 Skills/Obsidian/openclaw/references/operations.md` for agent references and operational notes
- Update agent composition tables in terminology notes
- Remove or archive related workspace notes

7. **Verify cleanup:**
```bash
openclaw agents list                    # Agent should be gone
crontab -l | grep <project-keyword>     # No cron entries
curl -s http://127.0.0.1:18789/health   # Gateway still healthy
```

## Reference

For architecture diagrams, agent composition, session protocol, heartbeat vs cron, and troubleshooting (삽질 기록), see [references/operations.md](50.%20AI/04%20Skills/Obsidian/openclaw/references/operations.md).

## Common Rationalizations
| Rationalization | Reality |
|---|---|
| "The agent will pick up the new channel binding immediately." | The binding is registered but the channel must also be in the guild allowlist. Without it, responses are silently dropped. |
| "I can skip IDENTITY.md for a quick test." | The agent will respond with the wrong identity, confusing users and polluting conversation history. Always create it. |
| "Editing SOUL.md takes effect immediately." | The gateway caches bootstrap files in memory. After editing, a gateway restart (`launchctl kickstart`) plus a session reset are both required. |
| "A session reset is enough to pick up SOUL.md changes." | Resetting the session (deleting the transcript) starts a new session, but the gateway still injects the old cached bootstrap. The gateway must be restarted first. |
| "I can put IDENTITY.md in agentDir." | Bootstrap files are loaded from the workspace directory, not agentDir. agentDir is for runtime state (sessions, auth). Confirm the workspace path via `agents.list[].workspace` in `openclaw.json`. |
| "Speech style goes in IDENTITY.md." | IDENTITY.md is for name/emoji/avatar metadata only. Speech style, tone, and personality belong in SOUL.md. |
| "Operational rules can go in BOOTSTRAP.md." | BOOTSTRAP.md is one-shot (deleted after first run). Persistent rules must go in AGENTS.md, which is loaded every session. |
| "Editing AGENTS.md takes effect immediately." | Existing sessions cache the previous AGENTS.md. Force a fresh session via gateway restart + session deletion. |
| "Maestro will use the correct OMX flags on its own." | Without an explicit `--madmax --high` rule in AGENTS.md, maestro starts sessions without those flags. Explicit rules are required. |
| "Removing the agent from the CLI is enough." | Cron entries, channel bindings, filesystem artifacts, and vault references all need separate cleanup. |
| "I'll manage the gateway process manually." | Gateway is launchd-managed. Use launchctl, not kill/nohup. |

## Red Flags
- Tailscale IPs, Discord tokens, bot tokens, or channel IDs appear in output
- Agent added without IDENTITY.md, SOUL.md, or USER.md
- Channel bound without verifying guild allowlist registration
- Cron entries left orphaned after agent removal
- Gateway managed via nohup instead of launchctl
- PATH not exported in cron scripts that use obsidian CLI
- Bootstrap files modified but gateway not restarted before testing via Discord or messenger
- Testing only via CLI without validating in Discord (CLI uses a direct session; Discord uses a group session and may behave differently)

## Verification
After completing the workflow, confirm:
- [ ] `tailscale ping m1-pro` confirmed reachability before SSH
- [ ] `openclaw agents list` reflects intended agent state
- [ ] No Tailscale IPs, Discord tokens, or channel IDs in output
- [ ] If agent added: IDENTITY.md, SOUL.md, USER.md exist in **workspace** directory (not agentDir)
- [ ] If channel bound: channel appears in guild allowlist
- [ ] If agent removed: no orphaned cron entries, channel bindings cleaned, filesystem artifacts removed
- [ ] If bootstrap files modified: gateway restarted (`launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway`)
- [ ] Gateway health check passes: `curl -s http://127.0.0.1:18789/health`
