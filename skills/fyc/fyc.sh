#!/bin/bash
# fyc: Fetch YouTube Content pipeline
# Usage: fyc.sh [date] [channel_ids...]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default channels (configure here)
DEFAULT_CHANNELS=""  # Add channel IDs when known

# Parse args - date is optional, defaults to today
DATE=$(date +%Y-%m-%d)
CHANNELS=""
for arg in "$@"; do
  if [[ "$arg" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    DATE="$arg"
  else
    CHANNELS="$CHANNELS $arg"
  fi
done
[[ -z "$CHANNELS" ]] && CHANNELS="$DEFAULT_CHANNELS"

if [[ -z "$CHANNELS" ]]; then
  echo "Usage: fyc.sh [YYYY-MM-DD] CHANNEL_ID1 [CHANNEL_ID2 ...]" >&2
  exit 1
fi

# Pipeline: fetch → capture URLs → filter → output
# Note: filter_videos.py takes URLs as positional args, not stdin
URLS=$(python3 "$SCRIPT_DIR/fetch_rss.py" "$DATE" $CHANNELS)

if [[ -z "$URLS" ]]; then
  echo "No videos found for $DATE" >&2
  exit 0
fi

# Pass captured URLs as args to filter
# shellcheck disable=SC2086
python3 "$SCRIPT_DIR/filter_videos.py" $URLS
