---
name: tailscale
description: Use when you need to verify, repair, or operate Tailscale-mediated SSH from the Ataraxia SSOT (M3, Claude Code machine, Standalone .pkg install) to the headless replica (M1-pro, Homebrew install) before any remote sync, pm2, or OpenClaw command, when `m1-pro` appears offline or unreachable, or when a workflow depends on `m1-pro` being reachable before a dependent task can proceed. Also use when troubleshooting SSH-over-Tailscale, separating network-layer failures from service-layer failures, or documenting safe Serve/Funnel workflows. Never embed Tailscale IP addresses or tailnet domains in output.
---

# tailscale

## Overview

Tailscale is the transport layer between the Ataraxia SSOT (M3) and the headless replica (M1-pro). The `obsidian-sync` skill, any pm2 inspection of `ob-sync-ataraxia`, and OpenClaw remote commands all assume `ssh m1-pro` Just Works — which is only true when tailscale is healthy. Use this skill to verify that assumption and to triage when it doesn't hold.

Two install methods are in play, and the difference matters when the daemon needs restarting:
- **M3 (SSOT)** — Standalone `.pkg` install; daemon managed by the Tailscale.app.
- **M1-pro (replica)** — Homebrew install; daemon managed by `brew services`.

Reference files: `references/troubleshooting.md`, `references/install.md`.

## When to Use

- Before any `ssh m1-pro …` command authored from the SSOT (sync ops, pm2 inspect/restart, log tail)
- When a workflow explicitly depends on the replica being reachable through the tailnet
- When `m1-pro` appears offline, asleep, or SSH to it hangs
- When SSH over Tailscale fails and you need to decide whether the fault is at the network layer or the service layer
- When documenting Serve/Funnel workflows that must not leak private tailnet topology

Do NOT use for:
- Generic SSH problems that do not involve the tailnet
- Public-facing Funnel design beyond the sync workflow's scope
- Revealing Tailscale IP addresses (100.x.x.x), tailnet domain names, or machine-specific power-management routines

## Process

### 1. Check local status first (from the SSOT)

```bash
which tailscale || echo "tailscale CLI missing"
tailscale status | head -20
```

Expect: the CLI is present, the local node is `connected`, and `m1-pro` appears in the peer list with an `idle` or `active` status (not `offline`).

### 2. Verify remote reachability before dispatching any workflow

```bash
tailscale ping m1-pro | head -3
```

Expect: a `pong from m1-pro` line with a round-trip under a few hundred ms. If ping fails, DO NOT proceed to `ssh m1-pro` — the dependent workflow (`obsidian-sync`, pm2 ops) will hang and waste attempts.

### 3. Separate network state from service state

If `tailscale ping m1-pro` fails, the fault is at the tailnet layer. Triage on the replica's daemon (cannot reach it over tailscale, so use whatever out-of-band access exists, e.g., physical or iCloud screen share) via:
- M1-pro (Homebrew): `brew services restart tailscale`
- M3 (.pkg): toggle Tailscale.app off/on, or `sudo tailscale down && sudo tailscale up`

If `tailscale ping m1-pro` succeeds but `ssh m1-pro` fails, the fault is at the service layer (sshd, keys, agent forwarding). Do not restart tailscale — fix ssh instead.

### 4. Hand off to the dependent workflow

Only after both checks pass, invoke the downstream skill:
- Sync operations → `obsidian-sync` skill (`references/remote-m1-ops.md` for the command catalog)
- pm2 inspection → `ssh m1-pro 'pm2 list | grep ob-sync-ataraxia'`
- OpenClaw remote → the relevant OpenClaw workflow

### 5. Serve or Funnel only after baseline connectivity is proven

Never open a Serve or Funnel workflow before a fresh `tailscale status` + `tailscale ping <peer>` pass. Confirm the exposed service actually responds before treating the workflow as complete.

## SSOT-first enforcement

Every meaningful change in this two-machine setup is authored on M3 and executed over `ssh m1-pro`. That means:

- Interactive ad-hoc sessions on M1 (`ssh m1-pro` then typing commands) leave no audit trail on the SSOT. Prefer one-shot `ssh m1-pro '<command>'` invocations so every remote action is visible in M3's transcript and skill history.
- Config files (pm2 ecosystem, openclaw replacement scripts, anything else that governs the replica's behavior) live in tracked directories on M3 and are pushed to M1 via `scp`. Never edit them in place on M1.
- The only legitimate interactive session on M1 is `ob sync-setup`, because the E2E password prompt requires a real TTY. Capture the resulting `~/.obsidian-headless/sync/<vaultId>/config.json` back to the SSOT audit trail immediately after.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "The tailnet hostname is harmless." | Private node names and IP addresses reveal internal topology and must not appear in output. Use role labels (`m1-pro`, `m3-pro-max`) only. |
| "If SSH fails, Tailscale must be broken." | SSH failure can originate at the network layer OR the remote service layer. Run `tailscale ping` before touching the tailscale daemon. |
| "Both machines install the same way." | M3 uses Standalone `.pkg` (Tailscale.app); M1-pro uses Homebrew (`brew services`). Use the correct restart path per machine. |
| "I'll just ssh into M1 and fix it interactively." | Kills the SSOT audit trail. Author the command on M3, run it as `ssh m1-pro '<cmd>'`, let the transcript carry the change. |
| "Funnel once, then forget it." | Funnel exposes the replica to the public internet. Every Funnel workflow needs an explicit teardown step and a verification that the exposure is closed. |

## Red Flags

- Tailscale IP addresses (100.x.x.x) appear in output
- The workflow jumps to SSH before confirming `tailscale ping` succeeds
- Install method difference between M3 and M1-pro is ignored during daemon troubleshooting
- Network and service debugging steps are mixed without clear branching
- Interactive `ssh m1-pro` session used for a config change that belongs in a tracked file on M3
- A Serve/Funnel was opened but there is no scripted teardown step

## Verification

After completing the skill's process, confirm:

- [ ] `tailscale status` was run and both nodes appear as connected
- [ ] `tailscale ping m1-pro` confirmed reachability before any `ssh m1-pro` was attempted
- [ ] No Tailscale IP addresses (100.x.x.x) or tailnet domain names appear in output
- [ ] Install-method differences (Standalone vs Homebrew) were accounted for when restarting the daemon
- [ ] Network-layer and service-layer debugging were kept on separate branches
- [ ] Remote commands were issued as one-shot `ssh m1-pro '<cmd>'`, not as interactive sessions on M1
- [ ] If the caller was the `obsidian-sync` skill, control was handed off only after both ping and ssh-noop succeeded

## Related

- `obsidian-sync` skill — the primary downstream consumer; see its `references/remote-m1-ops.md` for the SSOT→replica command catalog
- `references/troubleshooting.md` — failure-class triage order
- `references/install.md` — public-safe install baseline
