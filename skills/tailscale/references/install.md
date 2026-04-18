# Tailscale Install Reference

## Goal
Provide a public-safe installation baseline for Tailscale without embedding private machine assumptions.

## Public-Safe Principles
- Use the official Tailscale install flow for the target operating system.
- Prefer the documented CLI path for automation instead of personal shell aliases.
- Verify installation with a version or status command before continuing.

## Minimal Flow
1. Install Tailscale using the official package or installer for the target platform.
2. Confirm the CLI is available.
3. Authenticate through the supported login flow.
4. Verify that the node appears in the tailnet before continuing to SSH, Serve, or Funnel tasks.
