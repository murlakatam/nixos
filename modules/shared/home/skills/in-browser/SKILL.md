---
name: in-browser
description: "Open a real Chrome browser in a herdr side pane, using the rodney CLI, to show the user something or test it. Two jobs: (1) SHOW: open a temp file, a quick HTML render, a chart, an image, a PDF or any URL beside the chat so the user can look at it; (2) TEST: navigate pages, evaluate JavaScript, click elements and take screenshots over the Chrome DevTools Protocol. Pass mode=headless for unattended/pipeline use. MUST USE whenever the user says 'test' (or 'test it', 'test this', 'test the change') about anything that renders in a browser: a URL, a page, a UI or frontend change, a form, a flow. Also use when the user asks to 'show me', 'open it in the browser', 'render this', 'preview', 'test in browser', 'take a screenshot', 'check the UI', 'rodney', or when an agent wants the user to see a file or render without publishing it. Not for running a test suite (pytest, jest, yarn test). Pairs with build-a-demo (showboat) for full demo workflows."
compatibility: Claude Code — requires rodney binary in PATH and Google Chrome installed at /usr/bin/google-chrome-stable. Defaults to visible mode via the herdr terminal-browser plugin (herdr TUI or Herdr app, which open the pane differently) — falls back to headless outside herdr, or when a caller passes mode=headless.
allowed-tools: Bash(rodney *) Bash(terminal-browser *) Bash(browser-close *) Write Read
metadata:
  version: 2.1.0
  author: eugene
---

# Skill: in-browser

## Show the user a file or a quick render

To show the user something without publishing it, open it in the side pane
(visible mode, Step 1) instead of `about:blank`:

- **A local file:** pass `file://<absolute path>`. HTML, SVG, PNG, JPG, PDF,
  JSON and plain text all render.
- **A quick render you make:** write a self-contained HTML file to the
  scratchpad directory, then open it as a local file. Inline the CSS and data,
  so the page loads nothing it does not need.
- **A URL:** pass it as it is.

To show the next thing, reuse the pane: `rodney open <file:// or URL>`. To
refresh after you edit the file, run `rodney reload`. Leave the pane open for
the user, and stop there unless they asked for a test.

## Tell the user what is open

A pane the user forgets stays open, and every new one narrows their chat.

1. Before you open a pane, run `browser-close --list`. It prints one line per
   browser pane in this tab: the herdr pane and the page it shows. If this
   session opened one of them, show the new thing there with `rodney open`
   instead of opening another pane.
2. End the reply that opened a pane with one line that names what it shows
   and how to close it: `Showing <what> in the right pane. Say "close it", or
   run ! browser-close.` Say it once per pane, not on every turn.
3. If the user asks what is open, run `browser-close --list` and give them
   each pane and its page.
4. If the user says "close it", "done" or similar, run `browser-close`.

Drive a real Chrome browser from the CLI using **rodney**, a Go tool built on the [Rod](https://github.com/go-rod/rod) Chrome DevTools Protocol library. Designed for coding agents — `rodney --help` is the canonical reference.

## First: read the full help

```bash
rodney --help
```

Read this before every session. It lists every subcommand and flag.

## Mode: visible (default) vs headless

This skill takes a `mode` argument — `visible` or `headless`. **Default to
visible.** The user wants to watch the browser work in a herdr
terminal-browser pane, so start with `terminal-browser open`, never with
`rodney start`. Visible mode needs herdr (the TUI or the Herdr app, as
`herd-backend --strict` prints `tui` or `app`) and the `terminal-browser`
plugin; if either is missing, fall back to headless and say so in one line.
The two herdrs open the pane differently (Step 1).

Use `headless` only when a caller passes `mode=headless` in the skill args,
when the session is unattended (a scheduled or background run with nobody to
watch), or when the user says they do not need to watch. A pipeline step is
not a reason: if the user started the run, they are watching it.

Never pick `headless` because it is simpler, faster or what a nearby example
shows. If you catch yourself about to run `rodney start`, check the mode
first.

Headless mode drives an invisible background Chrome instead of a herdr
pane — same rodney commands, same output, the only difference is
startup/teardown (Steps 1 and 6 below) and that nothing is shown live.

## Core session flow

### 1 — Start the browser

**Visible (default), herdr TUI (`herd-backend --strict` prints `tui`):**

```bash
terminal-browser open about:blank --split right
PORT=$(terminal-browser ls --json | jq -r '.browsers[-1].cdpPort')
rodney connect "127.0.0.1:$PORT"
```

`terminal-browser ls --json` lists every running instance with its CDP
port; `[-1]` is the one you just opened. From here every rodney command
below is identical — it's driving the pane instead of a hidden process.

**Visible (default), Herdr app (`app`):** `terminal-browser open --split`
fails there ("could not work out which ghostty pane") and plain
`terminal-browser ls` is empty, because it filters to the current tab through
herdr's env. Start the browser as a terminal instead, and list with `--all`.
Use `herdr-compat`, not `herdr`: bare `herdr` is the TUI binary and fails in
the app with `server_not_running`.

```bash
BEFORE=$(terminal-browser ls --all --json | jq -c '[.browsers[].cdpPort]')
herdr-compat pane split --direction right --argv '["terminal-browser","open","about:blank"]' >/dev/null
for _ in $(seq 60); do
  PORT=$(terminal-browser ls --all --json | jq -r --argjson b "$BEFORE" '[.browsers[].cdpPort | select(. as $p | $b | index($p) | not)][0] // empty')
  [ -n "$PORT" ] && break; sleep 0.5
done
rodney connect "127.0.0.1:$PORT"
```

The split opens beside your own pane, in your tab, without moving the user's
focus. Picking the port that was not in `BEFORE` avoids attaching to another
session's browser, which `[-1]` could do under `--all`. Every rodney command
below is identical.

**Headless:**

```bash
rodney start
```

Starts Chrome in the background. Prints the PID and debug WebSocket URL. **Always call this first.**

### 2 — Navigate

```bash
rodney open https://localhost:5173/
```

### 3 — Evaluate JavaScript

```bash
rodney js 'document.title'
rodney js 'Array.from(document.querySelectorAll("h1")).map(el => el.textContent)'
```

Returns the result as JSON.

### 4 — Interact

```bash
rodney click 'button[type="submit"]'
rodney click 'a[href="/dashboard"]'
```

### 5 — Screenshot

```bash
rodney screenshot /tmp/feature-check.png
```

Saves a full-page screenshot. Use an absolute path. Pass the path to `showboat image` when building a demo.

### 6 — Stop / clean up

**Visible (default):** do **not** run `rodney stop` — it shuts down the
browser process, which would yank the pane out from under the user
mid-inspection. Just leave the pane; the user closes it themselves once
they're done looking.

To close it (only when the user asks, or when a caller says to clean up), run
`browser-close`. It closes the herdr pane of every browser opened from this
tab and stops the idle browser daemon once none are left. `browser-close --all`
also closes browsers other sessions opened; use it only when the user asks.
Do not use `terminal-browser shutdown` or `rodney stop` for this: they stop the
browser process but leave an empty herdr pane behind.

`browser-close` works the same in the herdr TUI and the Herdr app.

**Headless:**

```bash
rodney stop
```

Always stop when done — leaves no lingering Chrome process.

## Full example (visible, the default)

```bash
terminal-browser open about:blank --split right
PORT=$(terminal-browser ls --json | jq -r '.browsers[-1].cdpPort')
rodney connect "127.0.0.1:$PORT"
rodney open http://localhost:5173/
rodney js 'document.title'
rodney click 'nav a[href="/dashboard"]'
rodney js 'location.href'
rodney screenshot /tmp/page.png
# leave the pane open; do not run rodney stop
```

## Full example (headless)

Only for `mode=headless` or an unattended run:

```bash
rodney start
rodney open http://localhost:5173/
rodney js 'document.title'
rodney screenshot /tmp/page.png
rodney stop
```

## Pairing with build-a-demo

Use rodney screenshots inside a showboat demo:

```bash
showboat image demo.md 'rodney screenshot /tmp/page.png && echo /tmp/page.png'
```

A rodney session must already be connected (visible `terminal-browser open` + `rodney connect`, or `rodney start` for headless), earlier in the session.

## Accessibility testing

Rodney has built-in accessibility audit features — run `rodney --help` for the full list. Use these to check WCAG compliance on new pages before shipping.

## Notes

- Rodney uses the system Chrome. If Chrome isn't at `/usr/bin/google-chrome-stable`, check `rodney --help` for the browser path flag.
- One `rodney start` per session — don't start twice without stopping first. In visible mode, one `terminal-browser open` + `rodney connect` per session likewise — don't reconnect over a live session.
