#!/usr/bin/env python3
"""2-Tier YouTube video filter for FYC skill.

Tier 1: URL fast-pass — check /shorts/{id} HTTP status (200 = Short, skip)
Tier 2: Duration precision — yt-dlp batch duration check (< 300s = skip)

Usage:
    python3 filter_videos.py URL1 URL2 URL3 ...
    python3 filter_videos.py --tier1 URL1 URL2 ...   # Tier 1 only (no yt-dlp)

Output:
    stdout: kept URLs (one per line)
    stderr: skipped videos with reason (for FYC Phase 5 report)

Exit code: 0 always (filter never fails the pipeline)
"""

import http.client
import re
import subprocess
import sys
import urllib.parse
from concurrent.futures import ThreadPoolExecutor, as_completed


MIN_DURATION = 300  # 5 minutes


def extract_video_id(url_or_id: str) -> str:
    """Extract video ID from a YouTube URL or bare ID."""
    patterns = [
        r"(?:youtu\.be/)([a-zA-Z0-9_-]{11})",
        r"(?:youtube\.com/watch\?v=)([a-zA-Z0-9_-]{11})",
        r"(?:youtube\.com/embed/)([a-zA-Z0-9_-]{11})",
        r"(?:youtube\.com/shorts/)([a-zA-Z0-9_-]{11})",
    ]
    for pattern in patterns:
        match = re.search(pattern, url_or_id)
        if match:
            return match.group(1)
    if re.match(r"^[a-zA-Z0-9_-]{11}$", url_or_id):
        return url_or_id
    return ""


def check_shorts_url(video_id: str) -> bool:
    """Return True if YouTube considers this video a Short.

    Uses raw HTTP without redirect following -- a 303 redirect means
    YouTube does NOT serve it as a Short. A 200 means it IS a Short.
    """
    try:
        conn = http.client.HTTPSConnection("www.youtube.com", timeout=10)
        conn.request("HEAD", f"/shorts/{video_id}", headers={"User-Agent": "Mozilla/5.0"})
        resp = conn.getresponse()
        status = resp.status
        conn.close()
        return status == 200
    except Exception:
        return False


def tier1_filter(urls: list[str]) -> tuple[list[str], int]:
    """Tier 1: parallel URL check. Returns (survivors, skip_count)."""
    if not urls:
        return [], 0

    survivors = []
    skip_count = 0

    with ThreadPoolExecutor(max_workers=min(len(urls), 8)) as pool:
        futures = {}
        for url in urls:
            vid = extract_video_id(url)
            if vid:
                futures[pool.submit(check_shorts_url, vid)] = (url, vid)
            else:
                survivors.append(url)

        for future in as_completed(futures):
            url, vid = futures[future]
            try:
                is_short = future.result()
            except Exception:
                is_short = False
            if is_short:
                skip_count += 1
                print(f"SKIP [short]: {vid}", file=sys.stderr)
            else:
                survivors.append(url)

    return survivors, skip_count


def tier2_filter(urls: list[str]) -> tuple[list[str], int]:
    """Tier 2: batch yt-dlp duration check. Returns (kept, skip_count)."""
    if not urls:
        return [], 0

    kept = []
    skip_count = 0
    id_to_url = {extract_video_id(u): u for u in urls}

    try:
        result = subprocess.run(
            ["yt-dlp", "--print", "%(id)s %(duration)s", "--no-warnings"] + urls,
            capture_output=True, text=True, timeout=120,
        )
        if result.returncode != 0:
            print(f"WARNING: yt-dlp exit code {result.returncode}, keeping all Tier 1 survivors", file=sys.stderr)
            return urls, 0
        seen_ids = set()
        for line in result.stdout.strip().splitlines():
            parts = line.split(None, 1)
            if len(parts) < 2:
                continue
            vid, dur_str = parts
            seen_ids.add(vid)
            url = id_to_url.get(vid)
            if not url:
                continue
            try:
                duration = float(dur_str)
            except ValueError:
                kept.append(url)
                continue
            if duration < MIN_DURATION:
                skip_count += 1
                print(f"SKIP [duration {int(duration)}s]: {vid}", file=sys.stderr)
            else:
                kept.append(url)
        # Keep URLs that yt-dlp silently skipped (private, geo-blocked, etc.)
        for vid, url in id_to_url.items():
            if vid not in seen_ids:
                print(f"WARNING: yt-dlp returned no data for {vid}, keeping", file=sys.stderr)
                kept.append(url)
    except (subprocess.TimeoutExpired, FileNotFoundError) as e:
        print(f"WARNING: yt-dlp failed ({e}), keeping all Tier 1 survivors", file=sys.stderr)
        return urls, 0

    return kept, skip_count


def main():
    args = sys.argv[1:]
    tier1_only = "--tier1" in args
    if tier1_only:
        args.remove("--tier1")

    urls = [a for a in args if a.startswith("http")]
    if not urls:
        return

    # Tier 1
    survivors, t1_skipped = tier1_filter(urls)

    if tier1_only:
        for url in survivors:
            print(url)
        return

    # Tier 2
    kept, t2_skipped = tier2_filter(survivors)

    for url in kept:
        print(url)

    # Summary to stderr
    total = len(urls)
    final = len(kept)
    print(f"\n--- Filter Summary: {total} input -> {t1_skipped} T1 skip, {t2_skipped} T2 skip -> {final} kept ---", file=sys.stderr)


if __name__ == "__main__":
    main()
