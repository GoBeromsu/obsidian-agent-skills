# agent-browser Command Reference

## Navigation

| Command | Description |
|---|---|
| `open <url>` | Navigate to URL |
| `close` | Close browser (destructive — kills shared process) |
| `close --all` | Close all sessions |
| `tab` | List tabs |
| `tab new [url]` | New tab |
| `tab <n>` | Switch to tab |
| `tab close [n]` | Close tab |

## Observation

| Command | Description |
|---|---|
| `snapshot` | Accessibility tree with `@eN` refs (best for AI) |
| `snapshot -i` | Interactive elements only |
| `screenshot [path]` | Capture viewport |
| `screenshot --full` | Full page |
| `screenshot --annotate` | With numbered element labels |
| `get text <sel>` | Text content |
| `get html <sel>` | innerHTML |
| `get url` | Current URL |
| `get title` | Page title |
| `get value <sel>` | Input value |
| `get count <sel>` | Element count |
| `pdf <path>` | Save as PDF |

## Interaction

| Command | Description |
|---|---|
| `click <sel>` | Click element |
| `dblclick <sel>` | Double-click |
| `fill <sel> <text>` | Clear field + type text |
| `type <sel> <text>` | Type into focused element (appends) |
| `press <key>` | Press key (Enter, Tab, Control+a) |
| `select <sel> <val>` | Select dropdown option |
| `check <sel>` / `uncheck <sel>` | Toggle checkbox |
| `upload <sel> <files>` | Upload files |
| `hover <sel>` | Hover element |
| `scroll <dir> [px]` | Scroll (up/down/left/right) |
| `drag <src> <tgt>` | Drag and drop |

## Keyboard

```bash
keyboard type <text>           # real keystrokes
keyboard inserttext <text>     # insert without key events
keydown <key>                  # hold key
keyup <key>                    # release key
```

## JavaScript Execution

```bash
eval "<js>"                    # run JS in page context
eval -b "<base64>"             # base64-encoded script
```

Use when selectors/refs fail for complex interactions (SmartEditor, tinymce, site APIs).

## Semantic Locators (find)

When you have no snapshot ref or CSS selector:

```bash
find role button click --name "Submit"
find label "Email" fill "test@test.com"
find text "Sign in" click
find placeholder "Search..." type "query"
```

Actions: `click`, `fill`, `type`, `hover`, `focus`, `check`, `uncheck`, `text`.

## Waiting

```bash
wait <selector>                # element visible
wait <ms>                      # milliseconds
wait --text "Welcome"          # text on page
wait --url "**/dashboard"      # URL pattern
wait --load networkidle        # network idle
wait --fn "() => done"         # JS condition
wait <sel> --state hidden      # element disappears
```

## Clipboard

```bash
clipboard read
clipboard write "text"
clipboard copy                 # Ctrl+C
clipboard paste                # Ctrl+V
```

## Storage

```bash
cookies                        # list all
cookies set <name> <value>
cookies clear
storage local                  # list localStorage
storage local <key>
storage local set <k> <v>
storage session ...            # same for sessionStorage
```

## Network

```bash
network requests               # view tracked requests
network requests --filter api  # filter by URL
network route <url> --abort    # block requests
network har start
network har stop [output.har]
```

## Batch Execution

```bash
echo '[
  ["open", "https://example.com"],
  ["snapshot", "-i"],
  ["click", "@e1"]
]' | agent-browser batch --json
```

## Browser Configuration

```bash
set viewport <w> <h> [scale]
set device "iPhone 14"
set media dark
set offline on
```
