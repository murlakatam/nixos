---
name: build-a-demo
description: "Build a Markdown demo document that proves newly written code works — using the showboat CLI. Agents run showboat commands to capture shell output, screenshots, and notes into a self-contained demo.md. Use when the user asks to 'build a demo', 'demo this feature', 'show what you built', 'showboat', 'snowboat', or 'document this feature'. Pairs with in-browser (rodney) for screenshot capture."
compatibility: Claude Code — requires showboat binary in PATH
allowed-tools: Bash(showboat *) Bash(mmdc *) Bash(rodney *) Write Read
metadata:
  version: 1.1.2
  author: eugene
---

# Skill: build-a-demo

Build a living Markdown document that proves a feature works — not by describing it, but by running it and capturing the real output. Uses **showboat**, a Go CLI designed for coding agents to demonstrate their work.

## First: read the full help

Always run this before starting a demo session:

```bash
showboat --help
```

The help text is the canonical reference for every command and flag. Read it fully before issuing showboat commands.

## Core workflow

### 1 — Initialise

```bash
showboat init demo.md "Title of what you're demonstrating"
```

Creates `demo.md` with a heading and timestamp. Use a descriptive title — the user will share this file.

### 2 — Add prose

```bash
showboat note demo.md "Brief explanation of what the next command does."
```

### 3 — Run commands and capture output

```bash
showboat exec demo.md bash 'your-command --with-args'
```

The command runs for real. Stdout is captured and appended to `demo.md` immediately after the code block. **Never edit `demo.md` directly** — always go through showboat commands so the captured output is authentic.

### 4 — Capture screenshots (with rodney)

When the feature has a web UI, use rodney to take a screenshot then hand the file path to showboat:

```bash
showboat image demo.md 'rodney screenshot /tmp/feature-screenshot.png && echo /tmp/feature-screenshot.png'
```

Showboat's `image` command runs the inner command, looks for a file path in the output, copies the image into the current folder, and embeds it in the Markdown.

### 5 — Fix mistakes

If a section went wrong, pop the last entry and redo it:

```bash
showboat pop demo.md
```

## Output location

Save `demo.md` in the project root or a `demos/` folder unless the user specifies otherwise. Tell the user the path when done — they can open it in VS Code to see the live preview.

## Rules

- **Never write to `demo.md` directly.** Agents have been known to shortcut showboat and fabricate output — the whole point of showboat is that every captured block actually ran.
- Keep notes short — one sentence per `showboat note` call.
- The demo should be a working narrative: each `exec` proves the claim in the preceding `note`.
- End with a summary `note` of what was demonstrated.

## Rendering Mermaid diagrams

Use `mmdc` (mermaid-cli, replaces the claude-mermaid MCP which is blocked in Claude Code) to render a `.mmd` file to an image and embed it:

```bash
# Write the diagram to a file first
cat > /tmp/diagram.mmd << 'EOF'
graph TD
  A[Start] --> B[Process] --> C[End]
EOF

# Render to PNG and embed via showboat
showboat image demo.md 'mmdc -i /tmp/diagram.mmd -o /tmp/diagram.png && echo /tmp/diagram.png'
```

Or render standalone (no showboat):

```bash
mmdc -i diagram.mmd -o diagram.png          # PNG
mmdc -i diagram.mmd -o diagram.svg          # SVG
```

## Pairing with in-browser

For web features, use the `/in-browser` skill (rodney) to drive a real browser and capture screenshots, then embed them with `showboat image`.
