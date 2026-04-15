# Rize API Reference

## Goal
Provide a public-safe overview of the Rize API surface needed by this skill.

## Public Guidance
- Use the official Rize API endpoint and authentication flow documented by the provider.
- Keep API keys out of the skill body and out of committed example commands.
- Prefer aggregate summary queries first; use more detailed records only when the user explicitly needs them.

## Query Strategy
1. Choose the requested date range and output granularity.
2. Use summary-style queries for overview reporting.
3. Fall back to more detailed records only when the request cannot be answered from summaries.
4. Split oversized date ranges into smaller windows if the API struggles with very large responses.

## Verification
- Confirm the returned date range matches the request.
- Confirm the requested metric categories are actually present in the response.
