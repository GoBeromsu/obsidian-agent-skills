---
name: youtube-upload
description: >-
  Upload an mp4 video to YouTube with auto-generated metadata, custom thumbnail,
  SEO-optimized description with timestamps, and multi-language localization.
  Extracts transcript via mlx-audio (Qwen3-ASR), generates bilingual
  title/description/tags/chapters (English + Korean), creates a branded
  thumbnail (face photo + hook text, optionally over an Obsidian graph view
  background), uploads via YouTube Data API v3 with language metadata and
  localizations, and creates a tracked vault note in Obsidian. Use when the user
  says "upload video", "youtube upload", "영상 업로드", "publish video", or
  provides an mp4 path with upload intent. Also triggers on "영상 올려",
  "업로드 해줘", or when the user drops an mp4 file path in conversation. Do NOT
  use for downloading, clipping, or ingesting OTHER people's videos (use
  /youtube for that). Do NOT use for YouTube Shorts (blog-writer handles those).
---

# YouTube Upload Pipeline

Upload a local mp4 video to YouTube with auto-generated metadata, branded
thumbnail, and SEO-optimized description, then track it in the Obsidian vault.

## Overview

Pipeline: mp4 → ffmpeg audio extraction → transcript (mlx-audio) → bilingual
metadata + chapters + thumbnail → YouTube upload + language/localization → vault note.

Every upload gets:
- A branded thumbnail: face photo with bold hook text, optionally over
  an Obsidian graph view background
- An SEO-optimized description with timestamps/chapters generated from the
  transcript
- Bilingual metadata: primary language matching the spoken audio, plus a
  localized version in the other language (English ↔ Korean)
- Language metadata (`defaultAudioLanguage`) to enable YouTube auto-dubbing
- Automatic vault note tracking at `15. Work/02 Area/Youtube/`

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
  - `--language <code>` — original spoken language of the video (default: auto-detected from transcript). Sets `defaultAudioLanguage` on YouTube.
  - `--localize-ko "제목" "설명"` — override Korean localized title/description
  - `--localize-en "title" "desc"` — override English localized title/description

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
script). Determine the spoken language from the transcript's `language` field
(or from `--language` if provided). Generate all metadata in the **primary
language** (matching the spoken audio), then generate a **localized version** in
the other language (English ↔ Korean).

**Primary metadata** (in the spoken language):

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

**Tags** (5-12 relevant keywords as comma-separated list, include both languages)

**Thumbnail hook text** (3-5 word English hook):
- Must complement the title, not repeat it
- Use power words that trigger curiosity
- Examples: "THIS CHANGES EVERYTHING", "10X FASTER", "CODE WHILE SLEEPING"

**Localized metadata** (in the other language):

Generate a localized title and description for the alternate language. YouTube
displays these automatically to viewers whose language preference matches.
- If spoken language is `en`: generate `ko` localized title + description
- If spoken language is `ko`: generate `en` localized title + description
- The localized description should be a natural translation, not a machine-literal one

Save both primary and localized metadata for use in Steps 4 and 4.5.

If the user provided `--title`, `--description`, `--thumbnail-text`,
`--localize-ko`, or `--localize-en` overrides, use those instead of generating.

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
  --language "<spoken_language_code>" \
  --thumbnail /tmp/yt_thumbnail.jpg
```

The `--language` flag sets both `snippet.defaultLanguage` and
`snippet.defaultAudioLanguage` on YouTube. This tells YouTube what language the
video is spoken in, which is required for auto-dubbing to activate.

This outputs JSON to stdout:
```json
{"video_id": "abc123", "youtube_url": "https://www.youtube.com/watch?v=abc123"}
```

Parse and save `video_id` and `youtube_url`.

If upload.py exits with error about missing credentials, tell the user:
"Run `python3 $SKILL_DIR/scripts/upload.py --auth-only` to set up YouTube OAuth
credentials first."

If the thumbnail step was skipped, omit `--thumbnail` from the upload command.

### 4.5. Language & Localization

After upload succeeds, set localized titles and descriptions so YouTube shows
the right metadata to viewers in each language. This uses the YouTube Data API
`localizations` resource.

```bash
uv run "$SKILL_DIR/scripts/upload.py" --update "<video_id>" \
  --localizations '{"ko": {"title": "<ko_title>", "description": "<ko_desc>"}, "en": {"title": "<en_title>", "description": "<en_desc>"}}'
```

The script calls `videos().update(part="localizations")` to set localized
metadata without changing the primary snippet.

**Auto-dubbing reminder**: After upload, remind the user:
> To enable auto-dubbing, go to YouTube Studio → Settings → Content →
> Automatic dubbing and toggle it on. This cannot be done via API.
> Once enabled, YouTube will automatically generate dubbed audio tracks
> for eligible videos based on the `defaultAudioLanguage` you set.

Only show this reminder on the user's first upload, or if the language was
explicitly set via `--language`.

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
  path="15. Work/02 Area/Youtube/<title>.md" \
  content="$(cat /tmp/yt_upload_transcript.md)"
```

Then set frontmatter properties (key=value syntax, NOT --flag style):

```bash
NOTE_PATH="15. Work/02 Area/Youtube/<title>.md"

obsidian property:set vault=Ataraxia path="$NOTE_PATH" name=type value=video < /dev/null
obsidian property:set vault=Ataraxia path="$NOTE_PATH" name=video_id value="<video_id>" < /dev/null
obsidian property:set vault=Ataraxia path="$NOTE_PATH" name=source value="<youtube_url>" < /dev/null
obsidian property:set vault=Ataraxia path="$NOTE_PATH" name=date_published value="<YYYY-MM-DD>" < /dev/null
obsidian property:set vault=Ataraxia path="$NOTE_PATH" name=duration_seconds value="<duration>" < /dev/null
obsidian property:set vault=Ataraxia path="$NOTE_PATH" name=language value="<detected_or_specified_language>" < /dev/null
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
- Language: `<spoken_language>` (defaultAudioLanguage set)
- Localizations: `<list of locale codes set, e.g., en + ko>`
- Thumbnail: graph view / face-only / skipped
- Vault note: `15. Work/02 Area/Youtube/<title>.md`
- MoC tracking: visible in 📚 802 Youtube
- Auto-dubbing: remind if not previously mentioned

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "The auto-generated thumbnail is fine." | Auto thumbnails get 1-2% CTR. Custom thumbnails with face + text get 6-12%. Every upload without a custom thumbnail is a wasted impression. |
| "I'll add the thumbnail later." | You won't. The pipeline generates it in 2 seconds. There is no reason to skip it. |
| "The hook text doesn't matter much." | The hook text is 70-80% of what makes someone click. 3-5 power words that trigger curiosity are non-negotiable. |
| "A simple one-line description is enough." | Descriptions with timestamps, keywords, and links rank dramatically better in YouTube search. The extra 30 seconds of generation saves hours of obscurity. |
| "I can skip chapters/timestamps." | YouTube uses chapters for search indexing and video navigation. Skipping them means losing free SEO and worse viewer retention. |
| "Localization isn't worth the effort for a small channel." | YouTube serves localized titles/descriptions to viewers in their language preference automatically. A Korean viewer sees the Korean title; an English viewer sees the English one. This is free discoverability in two markets with zero extra distribution effort. |
| "I'll set the language later in YouTube Studio." | Setting `defaultAudioLanguage` at upload time is the trigger for auto-dubbing eligibility. Doing it later means the video misses the initial recommendation window when YouTube's algorithm pushes new uploads. |

## Red Flags

- Upload completes without a custom thumbnail
- Hook text repeats the full title instead of complementing it
- Hook text is longer than 5 words
- Description has no timestamps/chapters section
- Description has no hashtags
- Thumbnail step is skipped without warning the user
- Vault note created in 80. References/ instead of 15. Work/02 Area/Youtube/
- Transcript step skips ffmpeg extraction and fails on mp4 format
- Upload completes without `defaultAudioLanguage` set
- No localized metadata added (missing Korean or English localization)
- Language auto-detected as wrong language and not corrected

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
- [ ] Vault note created at `15. Work/02 Area/Youtube/`
- [ ] Language was set via `--language` or auto-detected from transcript
- [ ] `defaultAudioLanguage` and `defaultLanguage` were set on YouTube
- [ ] Localized title/description added for the alternate language (en↔ko)
- [ ] Auto-dubbing reminder shown to user (first upload or explicit --language)
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

- **Auto-dubbing cannot be enabled via the YouTube Data API v3.** It must be
  toggled in YouTube Studio → Settings → Content → Automatic dubbing. Setting
  `defaultAudioLanguage` via API is necessary but not sufficient — it tells
  YouTube what language the audio is in, but the creator must opt in to dubbing
  separately.

- **Expressive Speech does NOT support Korean (as of 2026).** The tone/emotion
  preservation feature only covers 8 languages: English, French, German, Hindi,
  Indonesian, Italian, Portuguese, Spanish. Korean auto-dubs use the standard
  (non-expressive) voice.

- **Auto-dubbing eligibility requirements.** The video must be under 120 minutes,
  have detectable speech, and the creator must have YouTube Partner Program or
  advanced features enabled. Not all videos qualify.

- **Multi-language audio track uploads are UI-only.** The YouTube Data API v3 has
  no endpoint for uploading additional audio tracks. Use YouTube Studio →
  Content → Edit video → Languages tab → Add dub for manual dub uploads.

## Transcript from existing YouTube videos (reference)

To extract a transcript from an already-published YouTube video (e.g., for English
review), use defuddle via agent-browser — this is NOT part of the upload pipeline:

```bash
# 1. Get the YouTube page HTML via agent-browser
agent-browser navigate "https://www.youtube.com/watch?v=<video_id>"
agent-browser extract  # returns defuddled content including transcript

# 2. Create vault note manually with the extracted transcript
obsidian create vault=Ataraxia path="15. Work/02 Area/Youtube/<title>.md" content="..."
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
