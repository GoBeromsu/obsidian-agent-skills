# Tailscale Troubleshooting Reference

## Goal
Provide a public-safe troubleshooting sequence for common Tailscale failures.

## Triage Order
1. Check whether the local client is installed and running.
2. Check whether the node is authenticated.
3. Check whether the remote node is reachable.
4. Only then test SSH or exposed services.

## Common Failure Classes
- CLI missing or not on PATH
- Client installed but disconnected
- Auth expired or login required
- Remote node offline or asleep
- Network healthy but service-layer problem still unresolved

## Rule
Do not publish real hostnames, private IPs, tailnet domains, or personal SSH targets in examples.
