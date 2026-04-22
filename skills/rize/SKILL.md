---
name: rize
description: Use when you need to query or summarize Rize productivity data, especially for focus-time analysis, productivity patterns, and structured output from a deterministic data-fetch workflow.
---

# rize

## Overview
Use this skill to fetch and summarize Rize productivity data via the GraphQL API. A deterministic shell script handles all parsing, API calls, preprocessing, and formatting end-to-end. The AI's role is to invoke the script with the user's request and pass the output through directly.

The script is invoked as:
```bash
FORMAT=markdown /path/to/fetch_rize_data.sh "<natural language request>"
```

`FORMAT=markdown` returns ready-to-use Obsidian markdown. Without `FORMAT`, returns raw JSON for programmatic use.

## Vault Access

Use the `obsidian-cli` skill for all note creation, edit, search, and property mutation inside the Ataraxia vault. Do not shell out to raw `cat`/`sed` on vault paths. See the `obsidian-cli` SKILL.md for the command surface and required preconditions (Obsidian must be running).

## When to Use
- Use when the user asks about Rize data, focus time, categories, or projects
- Use when a deterministic fetch-and-format workflow should produce structured output
- Use when the user wants a current week/month summary, custom date range, or category/project breakdown
- Do not use when the request has no connection to Rize or time-tracking data
- Do not hardcode personal local script paths in outputs or documentation

## Process

1. **Interpret the request**
   - Extract the target date range and requested metrics from the user's request.
   - The script handles all date parsing internally — pass the full natural language request string as-is.

   | Keyword in request | Effect |
   |---|---|
   | _(default)_ | Current week, no category breakdown |
   | `month` / `monthly` | Current month |
   | `today` | Today only |
   | `from YYYY-MM-DD to YYYY-MM-DD` | Custom date range |
   | `category` / `categories` | Include category breakdown |
   | `project` / `projects` | Include project breakdown |

2. **Run the deterministic fetch path**
   ```bash
   FORMAT=markdown /path/to/fetch_rize_data.sh "<user request>"
   ```
   - Pass the user's full request string. The script handles date calculation, GraphQL API calls, preprocessing, and formatting.
   - Use `FORMAT=markdown` for direct Obsidian output.
   - Omit `FORMAT` for raw JSON when programmatic use is needed.

3. **Return structured output**
   - When `FORMAT=markdown` is used, pass the script output through directly — no AI post-processing needed.
   - Add interpretation only if the user explicitly asked for it.
   - Example markdown output structure:
     ```markdown
     ## Rize — YYYY-MM-DD to YYYY-MM-DD

     **Focus Time**: 37h 9m

     ### Categories
     | Category | Time | % |
     |----------|------|---|
     | Code | 17h 44m | 35% |

     ### Projects
     | Project | Time | % |
     |---------|------|---|
     | My Project | 9h 33m | 54% |
     ```

4. **Verify**
   - Confirm the returned time window matches the user's request.
   - Surface failures explicitly instead of silently returning partial output.
   - If the fetch fails, report the error — do not fabricate or approximate data.

### Common Query Patterns

```bash
# Current week summary
FORMAT=markdown /path/to/fetch_rize_data.sh "this week"

# Current month with category breakdown
FORMAT=markdown /path/to/fetch_rize_data.sh "this month with categories"

# Custom date range with project breakdown
FORMAT=markdown /path/to/fetch_rize_data.sh "from 2026-04-01 to 2026-04-07 with projects"

# Raw JSON for programmatic use
/path/to/fetch_rize_data.sh "this week with categories"
```

### Reference Files

| Situation | Reference |
|-----------|-----------|
| GraphQL API details, timeout scenarios, workarounds | `references/api.md` |
| Default behavior, request parsing rules, customization | `references/pattern.md` |

### Limitations
- Category queries over 90-day ranges will timeout. Break into quarterly chunks.
- Data is pre-filtered (>1% threshold), sorted by time descending.
- Script defaults (`DEFAULT_PERIOD`, `DEFAULT_INCLUDE_CATEGORIES`, `BUCKET_THRESHOLD_DAYS`) are configurable at the top of `fetch_rize_data.sh`.

## Common Rationalizations
| Rationalization | Reality |
|---|---|
| "The exact script path is harmless to include." | Public skills should not depend on one personal filesystem layout. Use `/path/to/fetch_rize_data.sh`. |
| "The script output is probably for the right dates." | Always verify the returned time window against the user's request. |
| "Any productivity data is close enough." | The request often depends on a specific metric or time window — surface mismatches explicitly. |
| "I should format the output myself." | When `FORMAT=markdown` is used, the script output is final. Pass it through directly. |

## Red Flags
- Personal local script paths hardcoded in examples or outputs
- Date range of returned data not verified against the request
- Fetch failures silently ignored or data approximated
- AI reformats or summarizes markdown output that was already formatted by the script

## Verification
After completing the skill's process, confirm:
- [ ] Script was invoked with `FORMAT=markdown` and the user's full request string
- [ ] Returned time window explicitly matches the requested date range
- [ ] Failures are surfaced instead of silently ignored
- [ ] Output was passed through directly without unnecessary AI reformatting
- [ ] For category queries over 90 days, data was broken into quarterly chunks
