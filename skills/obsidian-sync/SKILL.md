---
name: obsidian-sync
description: Safely bootstrap, reconfigure, operate, or investigate `obsidian-headless` (ob CLI) sync between the Ataraxia SSOT (M3, GUI) and headless replicas (M1-pro, pm2 daemon). Use when the user wants to set up `ob sync` on a new machine, add/remove a vault sync config, flip modes (pull-only, bidirectional, mirror-remote), drive remote sync ops from SSOT via tailscale, inspect or restart the pm2 `ob-sync-ataraxia` daemon on M1, investigate files that may have been deleted by sync, recover from a silent-deletion incident, verify the multi-layer deletion defense stack, or asks about "ob sync", "obsidian sync", "obsidian-headless", "vault sync", "sync incident", "headless sync", "pm2 ob sync", or "m1 sync". The headless CLI can silently delete thousands of files on race conditions or remote corruption, so the safe path requires pull-only staging plus parity verification BEFORE bidirectional. All replica ops are authored on M3 and executed over `ssh m1-pro`; never author sync changes on the replica.
---

# Obsidian Sync

## Overview

The `obsidian-headless` CLI (`ob`) is a no-GUI sync client for Obsidian Sync. It is powerful but dangerous: a bad config, a corrupted remote, or a race condition with the Obsidian GUI can cascade into silent bulk deletion of notes across machines. This skill defines the safe bootstrap workflow, the daily operation surface, and the multi-layer defenses that must be in place before any `ob sync` command runs.

The operating principle: **every sync change is staged, verified with evidence, and reversible**. Never enable `bidirectional` or `--continuous` without first confirming parity in `pull-only` mode and having a git safety tag to roll back to.

## Topology (SSOT-first)

- **M3 (SSOT)** — primary machine, runs the Obsidian GUI, holds the authoritative vault at `/Users/beomsu/Documents/01. Obsidian/Ataraxia`. Claude Code and skill workflows execute here. Does NOT run `ob sync`.
- **M1-pro (headless replica)** — no GUI, runs `ob sync --continuous` under pm2 as `ob-sync-ataraxia`. The vault path mirrors M3 exactly.
- **Transport** — tailscale. All replica-side operations (pm2 inspect/restart, `ob` status, log tail, plist management) are driven from M3 by `ssh m1-pro …`. See `references/remote-m1-ops.md`.

If you are tempted to `ssh` into M1 and run `ob sync-setup` or edit pm2 config interactively, stop — invoke the workflow from M3 and let the remote command be the terminal leaf of an SSOT-authored plan.

## When to Use

- Adding, removing, or retargeting an `ob sync` vault config on any machine
- Switching sync mode (`bidirectional` <-> `pull-only` <-> `mirror-remote`)
- Setting up sync on a new headless replica
- Inspecting, restarting, or changing the pm2 `ob-sync-ataraxia` daemon on M1
- Investigating a vault where many files appear to be missing or recently deleted
- Verifying the multi-layer deletion defense stack after changes
- Post-incident recovery and drill runs

Do NOT use for:
- Obsidian GUI "Settings > Sync" configuration on M3 (different code path; handled in the GUI)
- `ob publish` publish-site operations (separate command family)
- Generic git conflict or rsync issues unrelated to Obsidian Sync
- Tailscale itself, beyond the SSOT→replica operational pattern (see the `tailscale` skill)

## Core Process

The safe bootstrap workflow runs in four phases: **Preflight -> Stage -> Verify -> Promote**. Each phase must finish with explicit evidence before the next begins. For daily operations against an already-bootstrapped replica, skip to the "Daily Operations" section below.

### Phase 1: Preflight

1. Confirm the role of each machine: M3 is SSOT (GUI), M1 is the replica (`ob sync` under pm2). Only the replica runs `ob sync`.
2. Take a git safety snapshot on every machine that owns a live vault:
   ```bash
   cd "<vault-path>"
   git add --update && git commit -m "pre-sync snapshot $(date -u +%Y%m%dT%H%M%SZ)"
   git tag "safety/pre-sync-$(date -u +%Y%m%d-%H%M%S)"
   ```
3. Capture the md file count (this is the invariant you will compare after):
   ```bash
   find "<vault-path>" -name "*.md" -not -path "*/.git/*" | wc -l
   ```
4. Confirm the multi-layer defense stack is installed and correct. See `references/defense-stack.md` for the full checklist; the short form:
   - PreToolUse hook exits 2 on piped deletion/push patterns
   - `.claude/settings.json` permission `deny` list covers `rm *`, `git rm *`, `git clean *`, `git push origin *`, `git push * --force*`
   - `.git/hooks/pre-commit` blocks bulk md deletions above a threshold
   - `git config --get core.hooksPath` is **empty or points to a real directory** (see Red Flags)
5. Confirm tailscale reachability to the replica before any remote operation:
   ```bash
   tailscale status | grep m1-pro
   tailscale ping --tsmp m1-pro | head -3
   ```
   If unreachable, fix connectivity first. See the `tailscale` skill for triage.
6. Close the Obsidian GUI on the replica and stop any launchd agent that re-spawns it (e.g., `ai.openclaw.gateway`, `ai.openclaw.gateway-watchdog`). See `references/launchd-respawn.md`.

### Phase 2: Stage (pull-only)

All commands in this phase target the replica. From M3, prefix each with `ssh m1-pro` (see `references/remote-m1-ops.md`) unless you are on the replica via an interactive terminal for the password-prompt step.

1. List the remote vaults and confirm the target vault still exists on the server — remote vaults can be deleted:
   ```bash
   ob sync-list-remote
   ```
2. List and remove any stale local configs that point to wrong paths or obsolete devices:
   ```bash
   ob sync-list-local
   ob sync-unlink --path "<stale-or-old-path>"
   ```
3. Pair the target local path to the remote vault. This prompts for the end-to-end encryption password interactively, so it must run in a real TTY (do not pipe `< /dev/null`, and do not invoke through a non-interactive ssh):
   ```bash
   ob sync-setup \
     --vault "<vault-id-or-name>" \
     --path "<local-vault-path>" \
     --device-name "<this-machine-name>"
   ```
4. Switch the new config to `pull-only` BEFORE the first sync. This is the single most important guard against an accidental destructive push:
   ```bash
   ob sync-config --path "<local-vault-path>" --mode pull-only
   ```
5. Run **one** non-continuous sync and capture output:
   ```bash
   ob sync --path "<local-vault-path>" 2>&1 | tee /tmp/ob-first-pull.log
   ```

### Phase 3: Verify

1. Re-measure the md file count. If the delta is larger than expected (for example, thousands of files changed when only days of drift were expected), STOP and investigate before proceeding.
2. Scan the sync log for error signatures:
   - `The connected remote vault no longer exists` -> the remote vault is gone; restart Phase 2 with a live vault
   - `Failed to authenticate: Vault not found` -> same as above
   - `Failed to validate password` -> wrong E2E password, retry `sync-setup`
3. Cross-check with `git status` and `git log`: the files that changed should be a plausible diff, not a wholesale wipe.
4. If any check fails, roll back with `git reset --hard safety/pre-sync-<timestamp>` and do not proceed.

### Phase 4: Promote

1. Flip mode to `bidirectional` once parity is confirmed and the diff makes sense:
   ```bash
   ob sync-config --path "<local-vault-path>" --mode bidirectional
   ```
2. Run one more one-shot sync and re-verify.
3. Only now enable continuous daemon mode. On M1-pro this is done under pm2 with a dedicated ecosystem file at `~/.config/pm2/ob-sync-ataraxia.config.cjs`; see `references/pm2-daemon.md` for the full config and healthcheck. Minimum-viable form:
   ```bash
   ob sync --path "<local-vault-path>" --continuous
   ```
4. Decide the fate of any launchd agents that were suspended in Phase 1. Two patterns apply (see `references/launchd-respawn.md`):
   - **One-shot bootstrap**: restore with `launchctl bootstrap gui/$(id -u) <plist>`.
   - **Continuous daemon (the M1-pro case)**: if the agent spawns the Obsidian GUI, delete the plist instead — a persistent daemon cannot coexist with recurring GUI spawns.

## Daily Operations (M3 → M1 over tailscale)

For a replica that is already bootstrapped and running under pm2, most ops are read-only inspections. All of the below run from M3. See `references/remote-m1-ops.md` for the full command catalog.

- **Health check** (should be a reflex before any sync change):
  ```bash
  ssh m1-pro 'pm2 list | grep ob-sync-ataraxia && tail -n 5 ~/.pm2/logs/ob-sync-ataraxia-out.log'
  ```
  Expect: `status=online`, low restart count, recurring `Fully synced` lines.
- **Restart daemon** (e.g., after a config edit on the replica):
  ```bash
  ssh m1-pro 'pm2 restart ob-sync-ataraxia --update-env && pm2 save'
  ```
- **Stop daemon immediately** (panic stop if a bad release is suspected):
  ```bash
  ssh m1-pro 'pm2 stop ob-sync-ataraxia'
  ```
  Stopping pm2 does not undo whatever was already synced — the git safety tag on the affected vault is what gets you back.
- **Change sync mode on the replica** (e.g., bidirectional ↔ pull-only):
  ```bash
  ssh m1-pro 'ob sync-config --path "/Users/beomsu/Documents/01. Obsidian/Ataraxia" --mode pull-only'
  ssh m1-pro 'pm2 restart ob-sync-ataraxia'
  ```
  A mode flip on a continuous daemon still requires a restart to re-read config.

Any operation more destructive than "inspect" (mode change, unlink, setup) must be preceded by a git safety tag on both M3 and M1 and followed by the Verify phase checks.

## Sync Modes

Pick the mode based on the risk budget. Modes are changed via `ob sync-config --mode`.

| Mode | Behavior | Safe to enable first time? |
|---|---|---|
| `bidirectional` (default) | Uploads local changes AND downloads remote changes. | No — never enable before a parity check. |
| `pull-only` | Downloads remote changes; ignores local-only files (keeps them). Remote deletions still apply locally. | Yes — this is the staging mode. |
| `mirror-remote` | Downloads remote changes AND reverts any local-only changes. Destructive to local. | No — only for "I want this machine to exactly mirror the server". |

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "Pull-only is completely safe, nothing can get deleted." | Remote deletions still propagate to local in pull-only mode. A corrupted remote can wipe files locally. |
| "The pre-commit guard will catch bulk deletions." | Only if `core.hooksPath` resolves to a real directory. Silent hook misconfig is a known incident vector; always `git config --get core.hooksPath` as part of preflight. |
| "Closing Obsidian GUI once is enough." | Launchd agents (e.g., `ai.openclaw.gateway`) can re-spawn the GUI within seconds. Both the agent and its watchdog must be suspended for the duration of the sync — or permanently removed on the continuous-daemon replica. |
| "v0.0.8 is the current npm release, so it must be stable." | v0.0.8 is the incident version that silently deleted thousands of files. Pin or stay on the last known-good version until a verified fix ships. |
| "The remote vault is the source of truth — just pull it." | The remote vault can be deleted or corrupted by the server side. See `references/incident-timeline.md` for the case where the remote vault vanished entirely. |
| "I'll skip the git safety tag, the vault is already in git." | A loose `HEAD` is not a named rollback point. Without the `safety/pre-sync-*` tag, rollback requires commit archaeology under time pressure. |
| "I'll just ssh into M1 and fix it there." | SSOT drift. Changes authored on the replica are invisible to M3's skill/plan history. Drive every change from M3; the ssh hop is the leaf, not the workspace. |

## Red Flags

Stop and investigate if any of these are observed:

- `ob sync-status` shows a vault path with a typo (e.g., missing `01. ` prefix) — high risk of misconfig, same class as the `core.hooksPath` bug
- `git config --get core.hooksPath` returns a path that does not exist
- `ob sync-list-remote` does not contain the vault you expect to sync to
- The first `ob sync` log contains `The connected remote vault no longer exists`
- The md file count after a pull changes by more than a few hundred when you only expected days of drift
- An unexpected Obsidian process keeps re-appearing in `ps` while you try to shut it down on the replica
- `encryptionVersion: 0` in the config.json on a fresh setup — current Obsidian Sync uses v3+; a v0 config is a stale leftover
- Sync-setup stalls with no password prompt — likely running in a non-TTY context (e.g., non-interactive ssh); re-run from a real terminal with `!` in the chat prompt
- `tailscale ping m1-pro` fails, OR `ssh m1-pro` works but `pm2 list` is empty — the replica is reachable but the daemon is gone; do not re-setup blindly, first inspect `~/.pm2/dump.pm2` and `~/.pm2/logs/`

## Verification

After any sync change, confirm:

- [ ] A `safety/pre-sync-*` git tag exists on every changed machine
- [ ] md file count delta is explained and plausible
- [ ] `ob sync-list-local` shows only the intended vaults and correct paths
- [ ] `ob sync-status` reports the expected mode and device name
- [ ] One non-continuous `ob sync` run completed cleanly before `--continuous` was enabled
- [ ] Defense stack verification: `echo '{"tool_input":{"command":"rm -rf x"}}' | .claude/hooks/block-git-dangerous.sh; echo $?` prints `2`
- [ ] Pre-commit guard drill: stage 101 nested md deletions on a throwaway branch, attempt commit, observe the guard block; separately commit a 2-file delete and observe it succeed
- [ ] On the replica: `pm2 list | grep ob-sync-ataraxia` shows `online`, restarts low, and logs carry a recent `Fully synced` heartbeat
- [ ] Any launchd agents stopped in Phase 1 are restored — or, on the continuous-daemon replica, confirmed permanently removed per `references/launchd-respawn.md`

For the full post-incident drill protocol, see `references/drill-protocol.md`.

## Related Files

- `references/remote-m1-ops.md` — SSOT→replica command catalog (tailscale-mediated pm2 / ob inspect / log tail / restart)
- `references/incident-timeline.md` — 2026-04-17 silent-deletion incident and the bugs it surfaced
- `references/defense-stack.md` — Layer 0/1/2 deletion defenses, config locations, and exit-code semantics
- `references/cli-commands.md` — `ob` command reference with flag-level detail
- `references/drill-protocol.md` — Step-by-step verification drill for the multi-layer defenses
- `references/launchd-respawn.md` — How to suspend, restore, or permanently remove Obsidian-respawning launchd agents
- `references/pm2-daemon.md` — pm2 ecosystem, healthcheck, and rollback for `ob sync --continuous` on the headless replica
