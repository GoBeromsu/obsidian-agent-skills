#!/usr/bin/env python3
"""Fetch YouTube RSS feeds and extract video URLs for a target date.

Usage:
    python3 fetch_rss.py YYYY-MM-DD CHANNEL_ID1 CHANNEL_ID2 ...

Output:
    stdout: video URLs (one per line)
    stderr: per-channel status for reporting

Exit code: 0 always (empty result is not an error)
"""

import sys
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor, as_completed
from urllib.request import urlopen

NS_YT = "{http://www.youtube.com/xml/schemas/2015}"
NS_ATOM = "{http://www.w3.org/2005/Atom}"


def fetch_channel(channel_id: str, target_date: str) -> list[str]:
    """Fetch RSS for a channel, return video URLs matching target_date."""
    url = f"https://www.youtube.com/feeds/videos.xml?channel_id={channel_id}"
    try:
        with urlopen(url, timeout=15) as resp:
            tree = ET.parse(resp)
    except Exception as e:
        print(f"ERROR [{channel_id}]: {e}", file=sys.stderr)
        return []

    videos = []
    for entry in tree.findall(f"{NS_ATOM}entry"):
        vid_el = entry.find(f"{NS_YT}videoId")
        pub_el = entry.find(f"{NS_ATOM}published")
        if vid_el is None or pub_el is None:
            continue
        if pub_el.text and pub_el.text.startswith(target_date):
            videos.append(f"https://www.youtube.com/watch?v={vid_el.text}")

    return videos


def main():
    if len(sys.argv) < 3:
        print("Usage: fetch_rss.py YYYY-MM-DD CHANNEL_ID1 [CHANNEL_ID2 ...]", file=sys.stderr)
        sys.exit(1)

    target_date = sys.argv[1]
    channel_ids = sys.argv[2:]

    seen = set()
    channels_with_uploads = 0

    with ThreadPoolExecutor(max_workers=min(len(channel_ids), 8)) as pool:
        futures = {
            pool.submit(fetch_channel, cid, target_date): cid
            for cid in channel_ids
        }
        for future in as_completed(futures):
            cid = futures[future]
            try:
                urls = future.result()
            except Exception as e:
                print(f"ERROR [{cid}]: unexpected: {e}", file=sys.stderr)
                continue
            if urls:
                channels_with_uploads += 1
                for url in urls:
                    if url not in seen:
                        seen.add(url)
                        print(url)
                print(f"  {cid}: {len(urls)} video(s)", file=sys.stderr)

    print(f"\n--- RSS Summary: {len(channel_ids)} channels, {channels_with_uploads} with uploads, {len(seen)} unique videos ---", file=sys.stderr)


if __name__ == "__main__":
    main()
