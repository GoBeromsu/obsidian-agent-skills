# Driving M1-pro Sync Operations from the M3 SSOT

All replica-side sync operations are authored on M3 (the SSOT) and executed on M1-pro via tailscale-backed SSH. This file is the command catalog.

## Why SSOT-first

- The vault and its git history live on M3. Changes authored on the replica shell do not appear in M3's plan/skill trace; the next agent session has no way to reconcile them.
- Tailscale gives us a stable hostname (`m1-pro`) regardless of which network M1 is on. Every command below assumes it resolves via the tailnet.
- The replica is treated as a cattle-class executor of SSOT-authored commands: no interactive editing, no in-place config changes, no ad-hoc one-off scripts that do not exist as files on M3.

Exception: `ob sync-setup` needs a real TTY for the E2E password prompt. Run it in an interactive terminal on the replica (either physically or via an interactive `ssh -t m1-pro`), then immediately capture the resulting config into the audit trail on M3.

## Preflight (run before any remote command)

```bash
# Network layer healthy?
tailscale status | grep m1-pro
tailscale ping --tsmp m1-pro | head -3
```

If either fails, fix tailscale before touching sync. See the `tailscale` skill for triage order.

```bash
# Service layer healthy?
ssh m1-pro 'pm2 list | grep ob-sync-ataraxia'
```

Expect `status=online`, restarts=0 or very low. If offline or missing, do NOT run `sync-setup` or restart blindly — read logs first.

## Inspect

```bash
# Daemon heartbeat
ssh m1-pro 'tail -n 20 ~/.pm2/logs/ob-sync-ataraxia-out.log'
# Expect recurring "Fully synced" every ~30s.

# Recent errors
ssh m1-pro 'tail -n 50 ~/.pm2/logs/ob-sync-ataraxia-err.log'

# Live structured pm2 row (portable alternative to jlist)
ssh m1-pro 'pm2 describe ob-sync-ataraxia | sed -n "1,40p"'

# ob sync state
ssh m1-pro 'ob sync-list-local'
ssh m1-pro 'ob sync-status --path "/Users/beomsu/Documents/01. Obsidian/Ataraxia"'
```

## Restart and reload

```bash
# Full restart (picks up args/env changes in the ecosystem file)
ssh m1-pro 'pm2 restart ob-sync-ataraxia --update-env && pm2 save'

# Graceful stop (does not remove from dump.pm2)
ssh m1-pro 'pm2 stop ob-sync-ataraxia'

# Resume
ssh m1-pro 'pm2 start ob-sync-ataraxia'

# Re-read ecosystem file after edit (M3 drives via scp; never inline edit on M1)
scp ~/config/pm2/ob-sync-ataraxia.config.cjs m1-pro:/Users/beomsu/.config/pm2/ob-sync-ataraxia.config.cjs
ssh m1-pro 'pm2 reload ~/.config/pm2/ob-sync-ataraxia.config.cjs && pm2 save'
```

The `scp` step is what keeps the SSOT property intact: the ecosystem file's canonical copy lives on M3 (tracked in whatever config directory M3 uses), and the replica receives a mirror.

## Mode changes (destructive — safety tag required)

```bash
# 1. Safety tag on both sides
cd "/Users/beomsu/Documents/01. Obsidian/Ataraxia"
git tag "safety/pre-mode-change-$(date -u +%Y%m%d-%H%M%S)"
ssh m1-pro 'cd "/Users/beomsu/Documents/01. Obsidian/Ataraxia" && git tag "safety/pre-mode-change-$(date -u +%Y%m%d-%H%M%S)"'

# 2. Stop the daemon before flipping mode — no concurrent reads/writes
ssh m1-pro 'pm2 stop ob-sync-ataraxia'

# 3. Flip mode
ssh m1-pro 'ob sync-config --path "/Users/beomsu/Documents/01. Obsidian/Ataraxia" --mode pull-only'

# 4. One-shot verify (non-continuous) before turning the daemon back on
ssh m1-pro 'ob sync --path "/Users/beomsu/Documents/01. Obsidian/Ataraxia" 2>&1 | tee /tmp/ob-mode-verify.log'
ssh m1-pro 'tail -n 30 /tmp/ob-mode-verify.log'

# 5. Resume daemon only after verifying the diff is sane
ssh m1-pro 'pm2 start ob-sync-ataraxia && pm2 save'
```

## Emergency stop (suspected bad release)

```bash
ssh m1-pro 'pm2 stop ob-sync-ataraxia'
# Then roll back on M3 using the safety tag from the most recent Phase 1 preflight:
cd "/Users/beomsu/Documents/01. Obsidian/Ataraxia"
git reset --hard safety/pre-sync-<timestamp>
```

Stopping pm2 does not undo what already synced. The git safety tag does.

## Patterns to avoid

| Anti-pattern | Why it's bad |
|---|---|
| `ssh m1-pro` then typing `ob sync-config …` interactively | No audit trail on M3; next agent session cannot see the change |
| Editing `~/.config/pm2/ob-sync-ataraxia.config.cjs` directly on M1 | SSOT drift — the replica's file diverges from the M3-tracked source |
| `ssh m1-pro 'ob sync-setup …'` (non-interactive) | Fails silently at the password prompt; may leave partial config |
| Running `pm2 restart` without `--update-env` after an ecosystem-file change | pm2 reuses the cached env; your change is invisible until a full delete+start |
| `tailscale ssh m1-pro` for destructive ops | Works, but bypasses your `~/.ssh/config` which is where SSOT-level connection hardening lives — prefer plain `ssh m1-pro` |

## Related

- `pm2-daemon.md` — the ecosystem file itself, healthcheck signals, and rollback
- `launchd-respawn.md` — why openclaw gateway plists were permanently removed on M1
- `cli-commands.md` — `ob` flag reference
- The `tailscale` skill — network-layer triage when `m1-pro` is unreachable
