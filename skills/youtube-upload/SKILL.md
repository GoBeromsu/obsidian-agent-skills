---
name: youtube-upload
description: >-
  Upload an mp4 video to YouTube with auto-generated metadata, custom thumbnail,
  and SEO-optimized description with timestamps. Extracts English transcript via
  mlx-audio (Qwen3-ASR), generates title/description/tags/chapters from the
  transcript, creates a branded thumbnail (face photo + hook text, optionally
  over an Obsidian graph view background), uploads via YouTube Data API v3, and
  creates a tracked vault note in Obsidian. Use when the user says "upload
  video", "youtube upload", "영상 업로드", "publish video", or provides an mp4
  path with upload intent. Also triggers on "영상 올려", "업로드 해줘", or when
  the user drops an mp4 file path in conversation. Do NOT use for downloading,
  clipping, or ingesting OTHER people's videos (use /youtube for that). Do NOT
  use for YouTube Shorts (blog-writer handles those).
---

# YouTube Upload Pipeline

Upload a local mp4 video to YouTube with auto-generated metadata, branded
thumbnail, and SEO-optimized description, then track it in the Obsidian vault.

## Overview

Pipeline: mp4 → ffmpeg audio extraction → transcript (mlx-audio) → metadata +
chapters + thumbnail → YouTube upload + set thumbnail → vault note.

Every upload gets:
- A branded thumbnail: face photo with bold English hook text, optionally over
  an Obsidian graph view background
- An SEO-optimized description with timestamps/chapters generated from the
  transcript
- Automatic vault note tracking at `12. Area/Youtube/`

## When to Use

- Use when uploading your own mp4 video to YouTube
- Use when the user says "upload video", "youtube upload", "영상 업로드"
- Use when the user provides an mp4 path with upload intent
- Do NOT use for downloading, clipping, or ingesting other people's videos
- Do NOT use for YouTube Shorts (blog-writer handles those)

## Input

- **Required**: mp4 file path
- **Optional**:
  - `--title "..."` — override generated title
  - `--description "..."` — override generated description
  - `--privacy private|unlisted|public` — default: public
  - `--playlist-id ID` — add to a playlist after upload
  - `--thumbnail-text "HOOK"` — override generated hook text
  - `--background` — use graph view background for thumbnail (default: face-only)

## Pipeline

Follow these steps sequentially. Each step must succeed before the next.

### 1. Extract audio and transcribe

mlx-audio cannot read mp4 containers directly. Extract audio to wav first:

```bash
ffmpeg -i '<mp4_path>' -vn -acodec pcm_s16le -ar 16000 -ac 1 /tmp/yt_audio.wav -y
```

Then transcribe:

```bash
SKILL_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)
uv run "$SKILL_DIR/scripts/transcribe.py" /tmp/yt_audio.wav
```

This outputs JSON to stdout:
```json
{"transcript": "...", "duration_seconds": 123.4, "language": "en"}
```

If duration_seconds > 3600, warn: "Video is over 1 hour. Transcription may take
several minutes."

Parse the JSON and save `transcript` and `duration_seconds` for the next steps.

### 2. Generate metadata

From the transcript, generate YouTube metadata yourself (do NOT call a separate
script). Generate all of these:

**Title** (up to 90 characters):
- Clear, specific, curiosity-triggering
- Include the primary topic and a hook

**Description** (SEO-optimized, with chapters):
```
[1-2 sentence hook — what the viewer will learn or see]

[3-5 key bullet points summarizing the content]

Timestamps:
0:00 Introduction
[MM:SS] [Chapter title from transcript topic shifts]
[MM:SS] [Chapter title]
...

[Links to tools/repos mentioned — GitHub, Obsidian, etc.]

[Call-to-action: subscribe, comment, like]

#Hashtag1 #Hashtag2 ... (5-10 relevant hashtags)
```

Chapters must start at 0:00, have at least 3 entries, and each be at least 10
seconds apart. Derive timestamps from the transcript's natural topic shifts.

**Tags** (5-12 relevant keywords as comma-separated list)

**Thumbnail hook text** (3-5 word English hook):
- Must complement the title, not repeat it
- Use power words that trigger curiosity
- Examples: "THIS CHANGES EVERYTHING", "10X FASTER", "CODE WHILE SLEEPING"

If the user provided `--title`, `--description`, or `--thumbnail-text` overrides,
use those instead of generating.

### 3. Generate thumbnail

Two modes are available:

**Graph view mode** (recommended, use when `--background` is specified or by default):
```bash
uv run "$SKILL_DIR/scripts/generate_thumbnail.py" \
  --face "$SKILL_DIR/assets/face.png" \
  --background "$SKILL_DIR/assets/graphview.png" \
  --text "<thumbnail_hook>" \
  --output /tmp/yt_thumbnail.jpg
```
Creates 1280x720 JPEG: Obsidian graph view background, dimmed overlay, bold
centered uppercase text, circular face inset in the bottom-right corner.

**Face-only mode** (fallback):
```bash
uv run "$SKILL_DIR/scripts/generate_thumbnail.py" \
  --face "$SKILL_DIR/assets/face.png" \
  --text "<thumbnail_hook>" \
  --output /tmp/yt_thumbnail.jpg
```
Creates 1280x720 JPEG: face fills canvas, dark gradient on left, bold text on
the left side.

If `assets/face.png` does not exist, skip this step and warn: "No face photo at
assets/face.png. Upload will proceed without custom thumbnail."

Before uploading, open the thumbnail locally for the user to review:
```bash
open /tmp/yt_thumbnail.jpg
```

### 4. Upload

```bash
uv run "$SKILL_DIR/scripts/upload.py" '<mp4_path>' \
  --title "<title>" \
  --description "<description>" \
  --tags "<tag1,tag2,...>" \
  --privacy public \
  --thumbnail /tmp/yt_thumbnail.jpg
```

This outputs JSON to stdout:
```json
{"video_id": "abc123", "youtube_url": "https://www.youtube.com/watch?v=abc123"}
```

Parse and save `video_id` and `youtube_url`.

If upload.py exits with error about missing credentials, tell the user:
"Run `python3 $SKILL_DIR/scripts/upload.py --auth-only` to set up YouTube OAuth
credentials first."

If the thumbnail step was skipped, omit `--thumbnail` from the upload command.

### 5. Check for duplicates

```bash
obsidian search vault=Ataraxia query="video_id: <video_id>"
```

If a note already exists with this video_id, warn the user and skip note
creation. Report the existing note path.

### 6. Create vault note

Write the transcript to a temp file first (avoids shell ARG_MAX for long videos):

```bash
cat > /tmp/yt_upload_transcript.md << 'TRANSCRIPT_EOF'
## Transcript

<transcript_text>
TRANSCRIPT_EOF

obsidian create vault=Ataraxia \
  path="12. Area/Youtube/<title>.md" \
  content="$(cat /tmp/yt_upload_transcript.md)"
```

Then set frontmatter properties (key=value syntax, NOT --flag style):

```bash
NOTE_PATH="12. Area/Youtube/<title>.md"

obsidian property:set vault=Ataraxia path="$NOTE_PATH" name=type value=video < /dev/null
obsidian property:set vault=Ataraxia path="$NOTE_PATH" name=video_id value="<video_id>" < /dev/null
obsidian property:set vault=Ataraxia path="$NOTE_PATH" name=source value="<youtube_url>" < /dev/null
obsidian property:set vault=Ataraxia path="$NOTE_PATH" name=date_published value="<YYYY-MM-DD>" < /dev/null
obsidian property:set vault=Ataraxia path="$NOTE_PATH" name=duration_seconds value="<duration>" < /dev/null
obsidian property:set vault=Ataraxia path="$NOTE_PATH" name=language value="en" < /dev/null
obsidian property:set vault=Ataraxia path="$NOTE_PATH" name=status value="done" < /dev/null
obsidian property:set vault=Ataraxia path="$NOTE_PATH" name=tags value="reference,reference/video,youtube/uploaded" type=list < /dev/null
obsidian property:set vault=Ataraxia path="$NOTE_PATH" name=title value="<generated_title>" < /dev/null
obsidian property:set vault=Ataraxia path="$NOTE_PATH" name=description value="<first_line_of_description>" < /dev/null
obsidian property:set vault=Ataraxia path="$NOTE_PATH" name=image value="https://img.youtube.com/vi/<video_id>/maxresdefault.jpg" < /dev/null
```

**Important**: 80. References/ is AI read-only (Edit/Write tools blocked by
hooks). Always use `obsidian create` and `obsidian property:set` via Bash —
these bypass the hook restriction.

### 7. Confirm

Report to the user:
- Video uploaded: `<youtube_url>`
- Privacy: `<privacy_status>`
- Thumbnail: graph view / face-only / skipped
- Vault note: `12. Area/Youtube/<title>.md`
- MoC tracking: visible in 📚 802 Youtube

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "The auto-generated thumbnail is fine." | Auto thumbnails get 1-2% CTR. Custom thumbnails with face + text get 6-12%. Every upload without a custom thumbnail is a wasted impression. |
| "I'll add the thumbnail later." | You won't. The pipeline generates it in 2 seconds. There is no reason to skip it. |
| "The hook text doesn't matter much." | The hook text is 70-80% of what makes someone click. 3-5 power words that trigger curiosity are non-negotiable. |
| "A simple one-line description is enough." | Descriptions with timestamps, keywords, and links rank dramatically better in YouTube search. The extra 30 seconds of generation saves hours of obscurity. |
| "I can skip chapters/timestamps." | YouTube uses chapters for search indexing and video navigation. Skipping them means losing free SEO and worse viewer retention. |

## Red Flags

- Upload completes without a custom thumbnail
- Hook text repeats the full title instead of complementing it
- Hook text is longer than 5 words
- Description has no timestamps/chapters section
- Description has no hashtags
- Thumbnail step is skipped without warning the user
- Vault note created in 80. References/ instead of 12. Area/Youtube/
- Transcript step skips ffmpeg extraction and fails on mp4 format

## Verification

After completing the skill's process, confirm:
- [ ] Audio was extracted from mp4 via ffmpeg before transcription
- [ ] Transcript was captured and parsed successfully
- [ ] Metadata includes title, description (with chapters/timestamps), tags, and hook text
- [ ] Description has timestamps starting at 0:00 with at least 3 chapters
- [ ] Description includes hashtags (5-10)
- [ ] Thumbnail was created at /tmp/yt_thumbnail.jpg (1280x720 JPEG)
- [ ] Thumbnail was shown to user for review before upload
- [ ] Video was uploaded and video_id was returned
- [ ] Custom thumbnail was set on YouTube
- [ ] Duplicate check passed (no existing note with same video_id)
- [ ] Vault note created at `12. Area/Youtube/`
- [ ] Frontmatter is complete (type, video_id, source, date_published, duration_seconds, language, status, tags, title, description, image)

## Do NOT

- Edit existing uploaded videos on YouTube
- Handle YouTube Shorts (blog-writer's domain)
- Auto-set visibility to unlisted or private unless the user explicitly requests it
- Use Edit or Write tools on files in `80. References/` (hooks will block it)
- Import `_get_credentials()` from blog-writer (hardcoded TOKEN_PATH)
- Pass mp4 directly to mlx-audio transcribe.py (will fail with miniaudio DecodeError)

## First-time setup

### Prerequisites
- GCP project: `obsidian-385509` (project number: `1084198536329`)
- YouTube Data API v3 must be enabled in this project
- Enable at: https://console.developers.google.com/apis/api/youtube.googleapis.com/overview?project=1084198536329
- ffmpeg must be installed (`brew install ffmpeg`)

### Manual setup
1. Ensure YouTube Data API v3 is enabled in your Google Cloud project
2. Download OAuth client ID JSON from Google Cloud Console
3. Save it to `~/.config/youtube-upload/credentials.json`
   (or symlink from gws: `ln -s ~/.config/gws/client_secret.json ~/.config/youtube-upload/credentials.json`)
4. Run: `uv run "$SKILL_DIR/scripts/upload.py" --auth-only`
5. Complete OAuth consent in browser (youtube.upload scope)
6. Place your face photo at `$SKILL_DIR/assets/face.png`
7. Optionally place an Obsidian graph view screenshot at `$SKILL_DIR/assets/graphview.png`

### Automated setup (agent-browser)
If the manual browser consent is blocked (headless environment, expired token):
1. Set env: `export OAUTHLIB_INSECURE_TRANSPORT=1`
2. Start OAuth flow with browser redirect captured:
   ```bash
   BROWSER=echo uv run "$SKILL_DIR/scripts/upload.py" --auth-only
   ```
   This prints the OAuth URL to stdout instead of opening a browser.
3. Open Chrome with remote debugging:
   ```bash
   /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --remote-debugging-port=9222
   ```
4. Use agent-browser to complete consent:
   ```bash
   agent-browser connect 9222
   agent-browser navigate "<oauth_url>"
   # agent-browser handles Google login + consent click automatically
   ```
5. Token is saved to `~/.config/youtube-upload/token.json`

## Caveats

- **mp4 format not supported by mlx-audio.** The miniaudio library cannot decode
  mp4 containers. Always extract audio to wav via ffmpeg before transcribing:
  ```bash
  ffmpeg -i input.mp4 -vn -acodec pcm_s16le -ar 16000 -ac 1 /tmp/yt_audio.wav -y
  ```

- **Custom thumbnails require phone verification.** Your YouTube channel must
  have phone verification enabled to set custom thumbnails via the API. Go to
  YouTube Studio → Settings → Channel → Feature eligibility if thumbnails.set()
  returns a 403.

- **`obsidian move` silently fails.** Use `obsidian eval` + `app.fileManager.renameFile()`
  instead when moving/renaming vault notes:
  ```bash
  obsidian eval vault=Ataraxia code="const f=app.vault.getAbstractFileByPath('old/path.md'); if(f) await app.fileManager.renameFile(f,'new/path.md');"
  ```
  This guarantees wikilink auto-update. Never use filesystem `mv`/`cp` inside the vault.

- **`obsidian property:set` hangs on stdin.** When called from a script or pipeline,
  property:set may block waiting for stdin. Append `< /dev/null` to each call:
  ```bash
  obsidian property:set vault=Ataraxia path="$NOTE_PATH" name=type value=video < /dev/null
  ```

- **`uv run` is required.** PEP 668 (Homebrew Python) blocks global `pip install`.
  All scripts use `# /// script` dependency headers so `uv run` auto-installs deps
  in an isolated env. Never `pip install` manually.

- **`OAUTHLIB_INSECURE_TRANSPORT=1` is set in upload.py line 37.** This allows the
  localhost OAuth callback over HTTP. Already handled in the script.

- **Apostrophes in filenames.** When the generated title contains `'`, use template
  literals (backtick strings) in `obsidian eval` code to avoid shell quoting issues.

## Transcript from existing YouTube videos (reference)

To extract a transcript from an already-published YouTube video (e.g., for English
review), use defuddle via agent-browser — this is NOT part of the upload pipeline:

```bash
# 1. Get the YouTube page HTML via agent-browser
agent-browser navigate "https://www.youtube.com/watch?v=<video_id>"
agent-browser extract  # returns defuddled content including transcript

# 2. Create vault note manually with the extracted transcript
obsidian create vault=Ataraxia path="12. Area/Youtube/<title>.md" content="..."
```

## Expected console output (successful run)

```
[ffmpeg] Extracting audio...
size=  20289KiB time=00:10:49.25 bitrate=256.0kbits/s
Loading model mlx-community/Qwen3-ASR-1.7B-8bit...
Model loaded in 3.9s
Transcribing: yt_audio.wav
Done: 24.9s, 4576 chars, 1073 tokens
{"transcript": "...", "duration_seconds": 649.3, "language": "en"}
Thumbnail saved: /tmp/yt_thumbnail.jpg (1280x720)
Uploading: my_video.mp4
Upload progress: 25%
Upload progress: 50%
Upload progress: 75%
Upload progress: 100%
Thumbnail set for dQw4w9WgXcQ
{"video_id": "dQw4w9WgXcQ", "youtube_url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"}
```
