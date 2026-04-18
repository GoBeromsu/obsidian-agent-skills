# Suspending Obsidian-respawning launchd agents

When running `ob sync` on a machine that also has the Obsidian GUI installed, the GUI must stay closed for the duration of the sync. On this user's setup (M1-pro specifically), several launchd agents re-spawn Obsidian automatically — `pkill Obsidian` alone is not sufficient.

## Identify what is respawning Obsidian

```bash
# Current parent of any live Obsidian process
ps -eo pid,ppid,user,command | grep -i "Obsidian.app/Contents/MacOS/Obsidian" | grep -v grep

# Walk up to the launch source
ps -p <PPID> -o pid,ppid,command
```

A common pattern on this user's machines: `ai.openclaw.gateway` (PID varies) is the parent process. It is launched by macOS `launchd` and has a watchdog, so killing it directly results in a fast relaunch.

## Locate the launchd plists

User-level agents live in `~/Library/LaunchAgents/`. Look for anything that references Obsidian or the gateway daemon:

```bash
ls -la ~/Library/LaunchAgents/ | grep -iE "obsidian|openclaw|gateway|vault"
launchctl list | grep -iE "obsidian|openclaw"
```

Typical set on this user's M1:

- `ai.openclaw.gateway.plist` — spawns Obsidian for daily-note and vault automation
- `ai.openclaw.gateway-watchdog.plist` — re-spawns the gateway if it dies
- `ai.openclaw.vault-watcher.plist` — fswatch on vault; does not spawn Obsidian directly
- `local.backup-openclaw.plist` — backup job; does not spawn Obsidian directly

The first two must be suspended during `ob sync`. The last two are safe to leave running.

## Suspend for the duration of the sync (user-authorized only)

This is a **user-gated action**. Do not run it without explicit approval — it temporarily disables the user's own automation. Present the commands and ask.

```bash
UID_=$(id -u)
launchctl bootout gui/$UID_ ~/Library/LaunchAgents/ai.openclaw.gateway-watchdog.plist
launchctl bootout gui/$UID_ ~/Library/LaunchAgents/ai.openclaw.gateway.plist

# Now kill the GUI and confirm it stays dead
pkill -f "Obsidian.app/Contents/MacOS/Obsidian"
sleep 5
pgrep -fl "Obsidian.app/Contents/MacOS/Obsidian" && echo "STILL ALIVE — abort sync" || echo "clear — proceed"
```

## Restore after sync

Always restore the agents, even if the sync failed.

```bash
UID_=$(id -u)
launchctl bootstrap gui/$UID_ ~/Library/LaunchAgents/ai.openclaw.gateway.plist
launchctl bootstrap gui/$UID_ ~/Library/LaunchAgents/ai.openclaw.gateway-watchdog.plist
launchctl list | grep openclaw   # confirm they are back
```

## Permanent removal (when `ob sync --continuous` is daemonised)

Once the vault is served by a long-lived daemon (e.g. pm2-managed `ob sync --continuous` as set up on 2026-04-18), "bootstrap" is no longer a bounded window — it is the whole lifetime of the machine's role. In that world, re-spawning the Obsidian GUI at all on the headless host creates the race the incident report warned about.

On 2026-04-18 the M1-pro `ai.openclaw.gateway` / `ai.openclaw.gateway-watchdog` plists were **deleted** (not just booted out) because the openclaw automation now runs as a separate, out-of-band service that does not depend on those agents. The vault-watcher and `local.backup-openclaw` plists were kept — they do not spawn Obsidian.

```bash
UID_=$(id -u)
launchctl bootout gui/$UID_ ~/Library/LaunchAgents/ai.openclaw.gateway.plist 2>/dev/null
launchctl bootout gui/$UID_ ~/Library/LaunchAgents/ai.openclaw.gateway-watchdog.plist 2>/dev/null
rm -v ~/Library/LaunchAgents/ai.openclaw.gateway.plist \
      ~/Library/LaunchAgents/ai.openclaw.gateway-watchdog.plist
```

Only take this step when:

- the machine is explicitly the headless replica, and
- the daily-note / vault automation that the gateway used to drive has an alternate runner (e.g. M3 GUI, or a standalone service), and
- the user has confirmed the deletion.

If any of those conditions is not met, keep the "suspend for the duration of the sync" pattern above instead.

## Why this matters

The 2026-04-17 incident investigation identified GUI-vs-headless race conditions as a contributing factor. Obsidian's background sync and `ob sync` both write to the same state database and the same set of files; if both run at once, one side's view of the world can lead the other to propagate "deletions" that are really in-flight edits.

The safest setup is: **M3 has the GUI and runs sync through the GUI; M1 is headless and runs `ob sync`.** During bootstrap, even a transient Obsidian GUI on M1 is unacceptable.

## Cross-platform note

On Linux (no Obsidian GUI): this file does not apply.

On Windows: the respawn surface is different (Task Scheduler, Startup folder, auto-relaunch via Electron). The general principle holds — find what is spawning Obsidian and suspend it for the sync window — but the exact commands differ.
