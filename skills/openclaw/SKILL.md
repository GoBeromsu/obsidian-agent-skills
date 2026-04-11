---
name: openclaw
description: Manage OpenClaw agent lifecycle on m1-pro — add/remove/modify agents, bind Discord channels, configure cron/heartbeat, check gateway health, and clean up deprecated agents (e.g., GSoC). Use when managing OpenClaw agents, cron jobs, gateway status, channel bindings, or agent cleanup tasks. Depends on tailscale skill for SSH connectivity.
---

# openclaw

## Overview
Operate the OpenClaw multi-agent gateway running on m1-pro. OpenClaw is the "지휘자" (conductor) — it receives messages from Discord/Telegram/Slack, routes them to the appropriate AI agent, and returns responses. This skill captures personal operational context that generic docs do not cover. For standard CLI reference and setup instructions, query NotebookLM MCP with the OpenClaw documentation.

Vault reference: `Ataraxia/50. AI/04 Workspaces/OpenClaw/` contains workspace definitions, agent protocols (AGENTS.md), and bootstrap guides (global.md).

## When to Use
- Adding, removing, or modifying agents (model change, identity update, skill assignment)
- Changing agent persona, speech style, or tone (SOUL.md)
- Binding or unbinding Discord channels to agents
- Managing cron jobs and heartbeat configurations
- Checking gateway health after reboot or network interruption
- Cleaning up deprecated agents and their resources (e.g., GSoC-related agents)
- Resetting a Discord session to pick up bootstrap changes (SOUL.md, IDENTITY.md)
- Updating agent skills in `~/.openclaw/skills/`
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
- `SOUL.md` — 말투, 톤, 성격 ("where your agent's voice lives"). 매 세션 첫 턴에 주입됨.
- `IDENTITY.md` — 이름, 이모지, 아바타 (메타데이터)
- `AGENTS.md` — 운영 규칙
- `TOOLS.md` — 로컬 설정 (SSH hosts, API keys)
- `USER.md` — 사용자 선호/맥락

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

### 7. Agent persona/speech style 변경

Bootstrap 파일(SOUL.md 등)은 **매 턴** 주입된다 (`contextInjection: "always"` 기본값). 단, 기존 Discord 세션은 이전 bootstrap을 캐시하므로 transcript 삭제 후 새 세션을 시작해야 변경이 반영된다.

**중요**: Bootstrap 파일은 **workspace 디렉토리**에서 로딩된다 (agentDir 아님). `openclaw.json`의 `agents.list[].workspace` 필드가 로딩 경로를 결정한다.

**말투/성격 변경:**
```bash
# SOUL.md 수정 (workspace root에 위치)
vi <workspace-path>/SOUL.md
```

**메타데이터(이름/이모지/아바타) 변경:**
```bash
vi <workspace-path>/IDENTITY.md
openclaw agents set-identity --agent <name> --from-identity
```

**변경 반영 — Discord 세션 리셋:**
기존 Discord 세션은 이전 bootstrap을 캐시하고 있으므로 transcript를 삭제해야 새 세션이 시작된다.
```bash
# 1. 세션 ID 확인
openclaw sessions --agent <name> --json

# 2. transcript 백업 후 삭제
cp ~/.openclaw/agents/<name>/sessions/<session-id>.jsonl /tmp/<backup-name>.jsonl
rm ~/.openclaw/agents/<name>/sessions/<session-id>.jsonl

# 3. sessions.json 정리
openclaw sessions cleanup --agent <name> --fix-missing --enforce
```
다음 Discord 메시지에서 새 세션이 시작되며 SOUL.md가 주입된다. Gateway 재시작은 불필요.

**CLI에서 테스트:**
```bash
# 새 session-id로 강제 새 세션
openclaw agent --agent <name> --session-id test-$(date +%s) --message '테스트 메시지'
```

### 8. Agent cleanup workflow (e.g., GSoC removal)

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
- Check `Ataraxia/50. AI/04 Workspaces/OpenClaw/openclaw.md` for agent references
- Update agent composition tables in terminology notes
- Remove or archive related workspace notes

7. **Verify cleanup:**
```bash
openclaw agents list                    # Agent should be gone
crontab -l | grep <project-keyword>     # No cron entries
curl -s http://127.0.0.1:18789/health   # Gateway still healthy
```

## Reference

For architecture diagrams, agent composition, session protocol, heartbeat vs cron, and troubleshooting (삽질 기록), see [references/operations.md](references/operations.md).

## Common Rationalizations
| Rationalization | Reality |
|---|---|
| "The agent will pick up the new channel binding immediately." | The binding is registered but the channel must also be in the guild allowlist. Without it, responses are silently dropped. |
| "I can skip IDENTITY.md for a quick test." | The agent will respond with the wrong identity, confusing users and polluting conversation history. Always create it. |
| "SOUL.md를 수정했으니 바로 반영될 거야." | Bootstrap은 매 턴 주입되지만, 기존 Discord 세션은 캐시된 bootstrap을 사용한다. transcript 삭제 후 새 세션을 시작해야 반영된다. |
| "agentDir에 IDENTITY.md를 넣으면 되지." | Bootstrap 파일은 workspace 디렉토리에서 로딩된다. agentDir는 세션/인증 등 런타임 상태 전용. workspace 경로는 `openclaw.json`의 `agents.list[].workspace`로 확인. |
| "말투는 IDENTITY.md에 넣으면 되지." | IDENTITY.md는 이름/이모지/아바타 메타데이터 전용. 말투/톤/성격은 SOUL.md에 넣어야 한다. |
| "Removing the agent from the CLI is enough." | Cron entries, channel bindings, filesystem artifacts, and vault references all need separate cleanup. |
| "I'll manage the gateway process manually." | Gateway is launchd-managed. Use launchctl, not kill/nohup. |

## Red Flags
- Tailscale IPs, Discord tokens, bot tokens, or channel IDs appear in output
- Agent added without IDENTITY.md, SOUL.md, or USER.md
- Channel bound without verifying guild allowlist registration
- Cron entries left orphaned after agent removal
- Gateway managed via nohup instead of launchctl
- PATH not exported in cron scripts that use obsidian CLI

## Verification
After completing the workflow, confirm:
- [ ] `tailscale ping m1-pro` confirmed reachability before SSH
- [ ] `openclaw agents list` reflects intended agent state
- [ ] No Tailscale IPs, Discord tokens, or channel IDs in output
- [ ] If agent added: IDENTITY.md, SOUL.md, USER.md exist in **workspace** directory (not agentDir)
- [ ] If channel bound: channel appears in guild allowlist
- [ ] If agent removed: no orphaned cron entries, channel bindings cleaned, filesystem artifacts removed
- [ ] Gateway health check passes: `curl -s http://127.0.0.1:18789/health`
