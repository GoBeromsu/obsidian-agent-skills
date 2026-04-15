---
name: fyc
description: Fetch YouTube Content — discover today's videos from subscribed channels, filter shorts, prepare for clipping. Scheduled daily via OpenClaw cron.
---

# fyc — Fetch YouTube Content

Daily YouTube channel monitoring skill. Fetches RSS feeds from subscribed channels, filters out Shorts and short-duration videos, downloads transcripts, and creates notes in the vault.

## Overview

Use this skill to run the daily YouTube content fetch pipeline. RSS feeds are polled per channel, videos are filtered with a 2-tier strategy, transcripts are downloaded, and notes are written to `80. References/05 Videos/`. Scheduled daily via OpenClaw cron.

## When to Use

- Use when the user wants to collect recent YouTube uploads into a note pipeline
- Use when channel discovery, transcript retrieval, and duplicate-safe note creation must happen as one workflow
- Use when a scheduled or repeatable fetch routine is needed
- Do not use for one-off manual video clipping when no repeatable pipeline is required

## Process

### Scripts

All scripts live in the skill directory:

| Script | Role |
|---|---|
| `fyc.sh` | Entry point — orchestrates the full pipeline |
| `fetch_rss.py` | Fetches YouTube RSS feeds, extracts URLs for target date |
| `filter_videos.py` | 2-tier filter: Shorts URL check + yt-dlp duration check |
| `obsidian_write_note.py` | Creates vault notes via obsidian CLI |

### Pipeline

```
fetch_rss.py → filter_videos.py → transcript download → obsidian_write_note.py
```

1. **fetch_rss.py** — Fetches YouTube RSS feeds for given channel IDs in parallel (up to 8 workers).
   - RSS endpoint: `https://www.youtube.com/feeds/videos.xml?channel_id=CHANNEL_ID`
   - Extracts video URLs published on the target date.

2. **filter_videos.py** — 2-tier filter:
   - **Tier 1 (URL fast-pass)**: HEAD request to `/shorts/{id}` — HTTP 200 means it's a Short, skip it.
   - **Tier 2 (Duration precision)**: `yt-dlp` batch duration check — videos under 5 minutes (300s) are skipped.

3. **Transcript download** — Passed URLs are fetched via defuddle (primary) or yt-dlp subtitles (fallback).

4. **obsidian_write_note.py** — Writes one note per video to `80. References/05 Videos/` using obsidian CLI.

### Usage

```bash
# Today's videos from specific channels
fyc.sh 2026-03-27 UCxxxxxx UCyyyyyy

# Today's date (default, uses channels from OpenClaw cron config)
fyc.sh

# Tier 1 only (no yt-dlp, faster)
python3 scripts/filter_videos.py --tier1 https://youtube.com/watch?v=abc
```

Direct script usage:

```bash
# Fetch only
python3 scripts/fetch_rss.py 2026-03-27 UCxxxxxx UCyyyyyy

# Filter only (pass URLs as args)
python3 scripts/filter_videos.py https://youtube.com/watch?v=abc https://youtube.com/watch?v=def
```

### Channel Configuration

Channel IDs are passed as arguments or configured in the OpenClaw cron job definition.

To find a channel ID:
- Go to the channel page → View Page Source → search for `channel_id`
- Or: `yt-dlp --print channel_id <channel_url>`

Channel authors have People notes in `70. Collections/01 People/`.

### Output

- Notes created at: `80. References/05 Videos/`
- **stdout**: Kept video URLs (one per line) — pipe to downstream tools
- **stderr**: Per-channel status, skip reasons, and summary stats

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "Any transcript is better than none." | Empty or embed-only transcripts create misleading low-quality outputs. |
| "Since this is scheduled, users don't need clear result reporting." | Scheduled pipelines need even clearer created/skipped/failed evidence. |
| "Tier 1 filter is enough." | Tier 1 misses non-Shorts short videos; Tier 2 duration check is required for accuracy. |

## Red Flags

- Duplicate or transcript quality checks are skipped
- Failed fetches still create placeholder notes
- Tier 2 filter is disabled without an explicit reason
- `obsidian_write_note.py` is bypassed with direct filesystem writes

## Verification

After completing the skill's process, confirm:
- [ ] RSS fetch returned results for each channel (check stderr summary)
- [ ] Tier 1 and Tier 2 filter counts are reported
- [ ] Notes exist in `80. References/05 Videos/` for each kept URL
- [ ] No placeholder notes emitted for failed transcript fetches
- [ ] The final report distinguishes created, skipped, and failed items

## Dependencies

- `python3` (stdlib only — no pip packages)
- `yt-dlp` (Tier 2 duration filter and transcript fallback)
- `defuddle` (primary transcript extractor)
- obsidian CLI (note creation via `obsidian_write_note.py`)
