---
name: openclaw
description: Manage OpenClaw agent lifecycle on m1-pro — add/remove/modify agents, bind Discord channels, configure cron/heartbeat, check gateway health, and clean up deprecated agents (e.g., GSoC). Use when managing OpenClaw agents, cron jobs, gateway status, channel bindings, or agent cleanup tasks. Depends on tailscale skill for SSH connectivity.
---

# openclaw

> [!warning] Deprecated (2026-04-21)
> OpenClaw is being replaced by [[Hermes Agent|Hermes]] on m1-pro. BNC/GDR cron and skill pipeline are moving to Hermes per `.omc/plans/2026-04-21-hermes-skill-pipeline-retarget.md`. This skill is preserved for 30 days as a rollback fallback; new work should target Hermes via `skill-deploy`'s Hermes leg.

## Overview
Operate the OpenClaw multi-agent gateway running on m1-pro. OpenClaw is the "지휘자" (conductor) — it receives messages from Discord/Telegram/Slack, routes them to the appropriate AI agent, and returns responses. This skill captures personal operational context that generic docs do not cover. For standard CLI reference and setup instructions, query NotebookLM MCP with the OpenClaw documentation.

Vault reference: `Ataraxia/50. AI/04 Skills/openclaw/` is the live vault source for this skill package and its supporting references.

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
- `SOUL.md` — 말투, 톤, 성격 ("where your agent's voice lives"). 매 턴 주입됨.
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

**변경 반영 — Gateway 재시작 + 세션 리셋:**
Gateway가 bootstrap 파일을 메모리에 캐시하므로, 파일 수정 후 반드시 Gateway를 재시작해야 한다. 세션 리셋만으로는 부족.
```bash
# 1. Gateway 재시작 (필수)
launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway
sleep 5
curl -s http://127.0.0.1:18789/health   # 정상 확인

# 2. 세션 ID 확인
openclaw sessions --agent <name> --json

# 3. transcript 백업 후 삭제
cp ~/.openclaw/agents/<name>/sessions/<session-id>.jsonl /tmp/<backup-name>.jsonl
rm ~/.openclaw/agents/<name>/sessions/<session-id>.jsonl

# 4. sessions.json 정리
openclaw sessions cleanup --agent <name> --fix-missing --enforce
```
다음 Discord 메시지에서 새 세션이 시작되며 새 SOUL.md가 주입된다.

**CLI에서 테스트:**
```bash
# 새 session-id로 강제 새 세션
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
- Check `Ataraxia/50. AI/04 Skills/openclaw/references/operations.md` for agent references and operational notes
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
| "SOUL.md를 수정했으니 바로 반영될 거야." | Gateway가 bootstrap 파일을 메모리에 캐시한다. 파일 수정 후 반드시 Gateway 재시작(`launchctl kickstart`) + 세션 리셋이 필요. |
| "세션 리셋만 하면 SOUL.md 변경이 반영될 거야." | 세션 리셋(transcript 삭제)은 새 세션을 시작하지만, Gateway가 캐시한 옛날 bootstrap을 그대로 주입한다. Gateway 재시작이 선행되어야 한다. |
| "agentDir에 IDENTITY.md를 넣으면 되지." | Bootstrap 파일은 workspace 디렉토리에서 로딩된다. agentDir는 세션/인증 등 런타임 상태 전용. workspace 경로는 `openclaw.json`의 `agents.list[].workspace`로 확인. |
| "말투는 IDENTITY.md에 넣으면 되지." | IDENTITY.md는 이름/이모지/아바타 메타데이터 전용. 말투/톤/성격은 SOUL.md에 넣어야 한다. |
| "BOOTSTRAP.md에 운영 규칙을 넣으면 되지." | BOOTSTRAP.md는 일회성(삭제됨). 매 세션 로딩되는 AGENTS.md에 넣어야 한다. |
| "AGENTS.md를 수정하면 바로 반영되지." | 기존 세션은 이전 AGENTS.md를 캐시한다. Gateway 재시작 + 세션 삭제로 새 세션을 강제해야 반영. |
| "maestro가 알아서 올바른 OMX 플래그를 쓰겠지." | AGENTS.md에 `--madmax --high` 강제 규칙이 없으면 maestro가 플래그 없이 세션을 시작한다. 명시적 규칙 필수. |
| "Removing the agent from the CLI is enough." | Cron entries, channel bindings, filesystem artifacts, and vault references all need separate cleanup. |
| "I'll manage the gateway process manually." | Gateway is launchd-managed. Use launchctl, not kill/nohup. |

## Red Flags
- Tailscale IPs, Discord tokens, bot tokens, or channel IDs appear in output
- Agent added without IDENTITY.md, SOUL.md, or USER.md
- Channel bound without verifying guild allowlist registration
- Cron entries left orphaned after agent removal
- Gateway managed via nohup instead of launchctl
- PATH not exported in cron scripts that use obsidian CLI
- Bootstrap 파일 수정 후 Gateway 재시작 없이 Discord/메신저에서 테스트
- CLI에서만 테스트하고 Discord 검증을 건너뜀 (CLI는 direct session, Discord는 group session으로 동작이 다를 수 있음)

## Verification
After completing the workflow, confirm:
- [ ] `tailscale ping m1-pro` confirmed reachability before SSH
- [ ] `openclaw agents list` reflects intended agent state
- [ ] No Tailscale IPs, Discord tokens, or channel IDs in output
- [ ] If agent added: IDENTITY.md, SOUL.md, USER.md exist in **workspace** directory (not agentDir)
- [ ] If channel bound: channel appears in guild allowlist
- [ ] If agent removed: no orphaned cron entries, channel bindings cleaned, filesystem artifacts removed
- [ ] If bootstrap files modified: Gateway 재시작 완료 (`launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway`)
- [ ] Gateway health check passes: `curl -s http://127.0.0.1:18789/health`
