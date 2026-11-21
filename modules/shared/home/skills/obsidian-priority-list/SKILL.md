---
name: obsidian-priority-list
description: "Review the Obsidian vault in tuicr and act on inline comments. Two modes. DEFAULT: build a priority task list from kanban Boards/ and map comments to board updates (done/defer/drop). INGEST: review a wide surface (Boards + Tasks/ + Projects/ + Goals/) and route every comment into /obsidian-ingest so the vault rewrites itself. Work and personal are kept strictly separate. Trigger default: /obsidian-priority-list, 'show my tasks', 'review outstanding tasks', 'priority list'. Trigger ingest: /obsidian-priority-list ingest, 'review and ingest', 'review my brain', 'brain review'."
compatibility: Designed for Claude Code
allowed-tools: Read Write Edit Glob Grep
metadata:
  version: 1.3.0
  author: eugene
---

# Skill: obsidian-priority-list

Builds a reviewable list from the vault, opens it
in tuicr for inline review, then acts on the user's comments.

**Vault:** `$OBSIDIAN_VAULT_PATH`, given in the "Vault path" section at the end of this skill. Use that value directly. Ask the user only if the section is missing.

**Work and personal are always kept strictly separate.**

---

## Modes

Pick the mode from how the skill was invoked, then follow the matching branches
in each step.

| | **Default mode** | **Ingest mode** |
|---|---|---|
| **Triggers** | `/obsidian-priority-list`, "show my tasks", "review outstanding tasks", "priority list" | `/obsidian-priority-list ingest`, "review and ingest", "review my brain", "brain review" |
| **Review surface** | kanban `Boards/` only | `Boards/` + `Tasks/` + `Projects/` + `Goals/` |
| **What comments do** | read in plain language and applied to the board (done / move next / defer / drop / edit) | every comment is routed into `/obsidian-ingest` so the vault rewrites itself — **no task-state edits** |

Step 3 (tuicr delegation) is identical in both modes. Steps 1, 2, and 4 branch
on the mode. **If unsure which mode, ask.**

---

## Step 1 — Read the review surface

### Default mode

Read unchecked tasks only from every `$OBSIDIAN_VAULT_PATH/Boards/*.md`. Classify
each board as work or personal from `_CLAUDE.md` or a host section at the end of
this skill. A board with no classification is personal.

Skip: `[x]` checked tasks, `kanban:settings` blocks, section headers.

### Ingest mode

Read the same boards (unchecked tasks only, same skips), **plus**:

- **Task notes:** every `$OBSIDIAN_VAULT_PATH/Tasks/*.md` — title (filename) + the
  first meaningful summary line of each.
- **Projects:** every `$OBSIDIAN_VAULT_PATH/Projects/*.md` — title + status/one-liner.
- **Goals:** every `$OBSIDIAN_VAULT_PATH/Goals/*.md` — title + one-liner.

Use `Glob`/`Grep` to enumerate; skip empty directories silently. While reading,
record for **every line** an internal map: `line → (title, vault-note-path)`.
The note-path is:

- For a **board item**: the most specific `[[wikilink]]` target inside the item
  (a `Knowledge/`, `Projects/`, or `Tasks/` page), else the board file itself.
- For a **Task / Project / Goal line**: the actual `.md` file path.

This map is what lets Step 4 tell `/obsidian-ingest` exactly which note each
comment is about.

---

## Step 2 — Build the review file

### Default mode

One task per line. Format:

```
# Priority List — YYYY-MM-DD

## 💼 Work Tasks

### 🚨 Overdue
T001 🔴 [2026-06-02] Send the quarterly report  [Ops]
T002 🟡 [2026-06-03] Review the draft proposal  [Docs]

### 📅 This week
T003 🔴 [2026-06-09] Write the API design doc  [API]
T004 🟡 [2026-06-09] Update project tickets  [API]

### 📆 Later
T005 🟢 [2026-06-15] Book team 1:1s  [Team]
T006 🟢 [2026-06-30] Spike the new search index  [API]

### ∞ No date
T007 🟡 Tidy the onboarding checklist  [Team]

---

## 🏠 Personal Tasks

### 🚨 Overdue / Due today
P001 🟡 [2026-06-07] Renew car registration

### 📅 This week
P002 🟡 [2026-06-12] Book flights
```

Rules:
- **Task IDs** (T001, P001) are session-local identifiers — stable within this run
- One line per task — no multi-line descriptions
- **Overdue** = past today's date
- Sort by due date within each section, then 🔴 > 🟡 > 🟢
- Project tag in `[brackets]` if present, e.g. `[API]`, `[Ops]`
- Never mix work and personal sections

### Ingest mode

One item per line across all four surfaces, each with a session-local ID.
Group by surface; keep work/personal separate within the board sections:

```
# Brain Review — YYYY-MM-DD

## 💼 Boards — Work
T001 🔴 [2026-06-09] Write the API design doc  [API]
T002 🟡 Turn the release steps into a playbook  [Team]

## 🏠 Boards — Personal
P001 🟡 [2026-06-12] Book flights

## 📓 Task Notes
K001 Investigate flaky integration tests — shared database contention
K002 Scope the new search index

## 🚀 Projects
J001 Public API — design in progress
J002 Home server — ongoing

## 🎯 Goals
G001 Ship the public API by Q3
```

Rules:
- ID prefixes: `T` work board, `P` personal board, `K` task notes, `J`
  projects, `G` goals — so a comment's line resolves unambiguously to a surface.
- One line per item — no multi-line bodies.
- Keep the **`line → (title, vault-note-path)`** map from Step 1 aligned with
  the line numbers you write here. This is the anchor Step 4 needs.
- Skip empty sections entirely.
- Never mix work and personal board sections.

---

## Step 3 — Delegate to tuicr-review

Hand off to the **tuicr-review** skill with:

- **content**: full text built in Step 2
- **filename**: `priority-list.md`
- **guidance** (mode-specific, paste verbatim):

*Default mode:*
> Comment on each task in plain words — `done` (or ✅ "finished") → mark
> complete; `next` / `move next` → push to next period; `defer friday` /
> `YYYY-MM-DD` / "next monday" → reschedule; `drop` → remove from board;
> anything else → applied as an edit or note. No verbs to memorise.

*Ingest mode:*
> Anchor a comment to any line and write the correction, update, or new context
> in plain language — it gets fed to /obsidian-ingest against the note that line
> points to. e.g. on a project line: `launch moved to March, Sam confirmed
> today`. Review-level comment (no anchor) → ingested as a general
> note. comment_type is ignored.

`tuicr-review` returns raw comment JSON, a verbal feedback string, or `null`
(user skipped). If `null`, report "Review skipped" and stop.

Resolve each returned comment's `start_line` to its item using the map kept in
Step 2 (default: `line → task ID`; ingest: `line → (title, vault-note-path)`).
Verbal feedback is treated as a review-level comment. How you act on the
resolved comments depends on the mode — see Step 4.

---

## Step 4 (default mode) — Apply updates to boards

**Ignore `comment_type`.** Read each comment's text and infer what the user
wants, then find the task in the source board by matching its title and apply it:

| What the comment means | Board change |
|---|---|
| done / finished / shipped / `✅` | `[ ]` → `[x]`, wrap title in `~~…~~`, append `✅ YYYY-MM-DD` |
| move next / next week / next sprint | Push `@{date}` forward one period (next week from today, or +1 sprint if the task is sprint-scoped) |
| defer to a date ("friday", "next monday", `YYYY-MM-DD`) | Replace `@{old-date}` with the resolved `@{new-date}` |
| drop / remove / kill | Remove the entire task block |
| a note or correction ("blocked on X", "Sam confirmed …") | Prepend `**Note (YYYY-MM-DD):** <text>` to the task body |
| an edit ("rename to X", "split into two") | Apply the edit to the task title/body |

When a comment is ambiguous, prefer the least destructive action (note over
drop) and say what you did in the summary so the user can correct it.

After all changes, print a compact summary:

```
✅ Marked done: T003 — Write the API design doc
⏭️  Moved next: T004 → 2026-06-29 — Update project tickets
📅 Deferred: T007 → 2026-06-16 — Tidy the onboarding checklist
🗑️  Dropped: T006 — Spike the new search index
📝 Noted on T005: "Sam confirmed most questions"
```

Append one log entry to `$OBSIDIAN_VAULT_PATH/log.md`:
```
## [YYYY-MM-DD] board | Priority review — N tasks updated via tuicr
```

---

## Step 4 (ingest mode) — Assemble a source and ingest

In ingest mode, **do not edit any board or task state.** Every comment is
knowledge to absorb. Steps:

### 4.1 — Assemble one structured source

For each comment, resolve `start_line` → `(title, vault-note-path)` via the
Step 2 map. Build a single source file preserving each comment **verbatim**
with its anchor. Review-level comments go under `## General notes` (no path).

Write it to `$OBSIDIAN_VAULT_PATH/raw/reviews/YYYY-MM-DD — Brain Review.md`
(`mkdir -p` the directory first). Frontmatter + body:

```md
---
date: YYYY-MM-DD
type: source
tags: [source, brain-review]
source_type: brain-review
ai-first: true
---
# Brain Review — YYYY-MM-DD

## Re: Search index spike  →  Knowledge/Search index.md
> launch moved to March — Sam confirmed YYYY-MM-DD

## Re: API design doc  →  Projects/Public API.md
> payload format locked, batch endpoint dropped from v1

## General notes
> <any review-level comments>
```

The `→ note-path` line is the anchor — it tells the ingest pass exactly which
note each comment targets, keeping the rewrite focused.

### 4.2 — Hand off to /obsidian-ingest

Invoke the existing ingest flow on the file you just wrote:

```
/obsidian-ingest $OBSIDIAN_VAULT_PATH/raw/reviews/YYYY-MM-DD — Brain Review.md
```

The ingest pipeline reads the source, rewrites the anchored notes
(entities, concepts, projects), resolves contradictions, synthesises any
emerging patterns, updates `index.md` + `log.md`, and reports back what changed.
Do **not** re-implement that logic here — delegate to it.

### 4.3 — Report

Surface the ingest pipeline's own report (pages rewritten, contradictions
resolved, synthesis pages created). No extra log line is needed — `/obsidian-ingest`
writes its own.

---

## Notes

- **Never mix work and personal** — the user explicitly asked for strict separation
- The temp repo at `/tmp/` is ephemeral — leave it; the OS will clean it up
- IDs (T/P/K/J/G) reset each run — they are not stable across sessions
- The review is read-only until the user comments; don't auto-update boards or
  ingest anything without comments
- **Ingest mode never edits task state** — board/task changes only happen in
  default mode. If the user wants both in one sitting, run the two modes
  separately.
- This skill writes only the `raw/reviews/` source and
  delegates the rewrite to `/obsidian-ingest`.
