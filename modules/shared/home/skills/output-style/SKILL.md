---
name: output-style
description: "Manage Claude Code output styles. Modes: switch (default, activate a style), change (create or refine a named style interactively), test (draft a style from freeform text, fast, no questions), list (show available styles), clear (reset to Claude Code's built-in Default). Trigger: 'output style', '/output-style', 'switch style', 'change my style', 'test this style', 'list output styles', 'clear output style', 'reset to default style'."
allowed-tools: Read Write Edit Bash(find *) AskUserQuestion
metadata:
  version: 2.0.0
  author: eugene
---

# Skill: output-style

Manages Claude Code **output styles**: whole-conversation tone and behavior
overrides, distinct from skills (invoked contextually) and hooks (fire on
events).

## What an output style actually is

- **File**: `~/.claude/output-styles/<name>.md`, or `.claude/output-styles/`
  in a project.
- **Frontmatter**: `name` (optional, inherits from filename), `description`
  (optional, shown in `/config`'s picker), `keep-coding-instructions` (bool,
  default `false`), `force-for-plugin` (plugins only). **The frontmatter
  `name:` is what `outputStyle` matches, not the literal filename.** Keep the
  two aligned (case included) unless there's a reason not to.
- **Body behavior**: appended to Claude Code's system prompt. Claude's built-in
  coding instructions are **removed** unless `keep-coding-instructions: true`
  is set. For anything meant to change tone or voice while staying a working
  coding assistant, set it to `true`.
- **Active style**: the `outputStyle` key in `~/.claude/settings.json`. Remove
  the key, or set it to `Default`, for the built-in default.
- **Built-in styles** (need no file): `Default`, `Proactive`, `Explanatory`,
  `Learning`.
- **Never name a custom style the same as a built-in** (exactly or by close
  spelling). Official docs don't define what happens on a collision. Check the
  name against this list when drafting in `change` or `test` mode.

## Where to make the change

If this file ends with a **Host setup** section, follow it: it says where this
host keeps its styles and active style, and how to apply a change.

Otherwise edit the two paths above directly. If either is a read-only or Nix
store symlink, don't force it. Tell the user it is managed elsewhere and ask
where the source lives.

## Modes

Default to **switch** if the user's request doesn't name a mode.

### switch: activate a style

1. If a style name wasn't given, run **list** first and ask which one
   (`AskUserQuestion`, one option per style + "Default").
2. Set the active style to `<name>`.

### clear: reset to Claude Code's built-in Default

1. Clear the active style.
2. Say plainly that Claude Code is back on its built-in Default.

### change: create or refine a named style, interactively

1. If the style doesn't exist yet, or the ask is vague, use `AskUserQuestion`
   to settle: the voice or behavior wanted, whether it should keep full
   coding-assistant behavior (`keep-coding-instructions: true`) or replace it,
   and anything it should avoid. Don't guess a persona from one line.
2. Write or edit the style file: correct frontmatter, and a body in the
   imperative ("Write like...", "Prefer..."), not a description of the style.
3. Offer to **switch** to it. Don't switch without asking, because `change` can
   also mean updating a style that isn't active.

### test: draft a style from freeform text, fast

1. Derive a short kebab-case name from the input. Don't ask for a name unless
   nothing reasonable can be derived.
2. Draft the style file directly from the text, with no clarifying questions.
   Use `keep-coding-instructions: true` unless the text clearly asks to replace
   coding behavior entirely.
3. **Switch** to it immediately.

### list: show available styles

Run `find ~/.claude/output-styles -name '*.md'`, read each file's `description`
frontmatter, and print name + description. Include the four built-ins with a
note that they need no file. Mark the one matching the active style.

## Notes

- A style takes effect after the next `/clear` or session start. Say so after a
  `switch` or `test`.
- Output styles apply to the **main conversation only**, not subagents.
