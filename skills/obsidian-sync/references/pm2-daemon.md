# Daemonising `ob sync --continuous` with pm2

Once the Stage -> Verify -> Promote sequence is complete on a headless replica, the last step is to run `ob sync --continuous` as a supervised daemon. pm2 is the chosen supervisor on this user's M1-pro: it survives logout, auto-restarts on crash, and integrates with the existing `pm2.beomsu.plist` at `/Library/LaunchDaemons/` so the whole stack comes back after a reboot without any sudo at sync time.

Do not set up pm2 on a machine that still has the Obsidian GUI respawning — see `launchd-respawn.md` for the gateway/watchdog issue. A continuous daemon turns every transient GUI spawn into a GUI-vs-headless race.

## One-time preconditions

- `ob --version` reports a known-good version (currently the last known-good at the time of writing is the version immediately preceding the 2026-04-17 incident; see `cli-commands.md`).
- `ob sync-status --path "<vault>"` reports `bidirectional` (Phase 4 promote complete).
- `pm2 --version` works for the user (not root).
- `/Library/LaunchDaemons/pm2.<user>.plist` is installed (one-time sudo step, done long before bootstrap).

## Ecosystem file

On M1-pro this lives at `~/.config/pm2/ob-sync-ataraxia.config.cjs`. Keep it in `~/.config/pm2/` rather than inside the vault so the vault stays pure-content.

```javascript
module.exports = {
  apps: [{
    name: "ob-sync-ataraxia",
    script: "/opt/homebrew/bin/ob",
    args: [
      "sync",
      "--path", "/Users/beomsu/Documents/01. Obsidian/Ataraxia",
      "--continuous"
    ],
    interpreter: "none",          // ob is a Node shebang binary; let it interpret itself
    cwd: "/Users/beomsu",
    autorestart: true,
    restart_delay: 5000,          // back off between crash-loops
    max_restarts: 20,             // stop thrashing if something is fundamentally wrong
    min_uptime: "30s",
    kill_timeout: 10000,          // let ob finish a flush before SIGKILL
    out_file: "/Users/beomsu/.pm2/logs/ob-sync-ataraxia-out.log",
    error_file: "/Users/beomsu/.pm2/logs/ob-sync-ataraxia-err.log",
    merge_logs: true,
    time: true,                   // prefix every log line with a timestamp
    env: {
      NODE_ENV: "production",
      PATH: "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
    }
  }]
};
```

Key choices and why:

- `interpreter: "none"` — `ob` is already a Node shebang; pm2 should not try to wrap it in another Node process.
- `restart_delay` + `min_uptime` + `max_restarts` — together they break a crash loop instead of burning CPU forever on a persistent error.
- Logs under `~/.pm2/logs/` rather than the vault — log noise in the vault would confuse sync parity checks.
- `time: true` — human-readable timestamps; "Fully synced" lines are the canonical heartbeat.

## Start and persist

```bash
pm2 start ~/.config/pm2/ob-sync-ataraxia.config.cjs
pm2 save                               # write ~/.pm2/dump.pm2
pm2 startup launchd -u "$USER" --hp "$HOME"   # prints the sudo command to install boot persistence (already installed on this user's M1-pro, noop re-run is safe)
```

`pm2 save` writes the process list to `~/.pm2/dump.pm2`. When the system reboots, `/Library/LaunchDaemons/pm2.<user>.plist` launches pm2, which reads the dump and resurrects `ob-sync-ataraxia`. No sudo is needed at sync time after the one-time startup install.

## Healthcheck

A healthy daemon shows:

```bash
pm2 list | grep ob-sync-ataraxia
# expected: status=online, restarts=0 or very low, uptime matching when you started it
tail -n 3 ~/.pm2/logs/ob-sync-ataraxia-out.log
# expected: recurring "Fully synced" lines every ~30 seconds
```

Warning signs:

- `restarts` incrementing — open `~/.pm2/logs/ob-sync-ataraxia-err.log` before doing anything else.
- `Fully synced` heartbeat stops — the vault is either disconnected or the server stopped responding; check network and `ob sync-status`.
- RAM climbing past ~500 MB steady state for this vault size — restart with `pm2 restart ob-sync-ataraxia`.

## Stop, restart, inspect

```bash
pm2 stop ob-sync-ataraxia         # pause; dump.pm2 still remembers it
pm2 start ob-sync-ataraxia        # resume
pm2 restart ob-sync-ataraxia      # full restart
pm2 logs ob-sync-ataraxia --lines 200   # tail logs live
pm2 delete ob-sync-ataraxia       # forget about it; remember to `pm2 save` after
```

If you change `ob-sync-ataraxia.config.cjs`, run `pm2 restart ob-sync-ataraxia --update-env` to pick up the new args/env, then `pm2 save`.

## Rolling back

pm2 is not a sync guard. If a bad `ob` release is deleting files, the guard is Layer 2 (pre-commit) plus the git safety tag from Phase 1 — the pm2 daemon should be stopped immediately:

```bash
pm2 stop ob-sync-ataraxia
```

Stopping pm2 does not undo whatever was already synced. The git safety tag is what gets you back.
