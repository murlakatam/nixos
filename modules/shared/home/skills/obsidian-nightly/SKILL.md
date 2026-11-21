---
name: obsidian-nightly
description: "Evening reflection workflow — fetch the day's calendar meetings, reflect on each one with the user, fill in the 🌙 Evening Review section of the daily note, set tomorrow's top priorities, and optionally draft (never send) follow-up emails for action items. Also sweeps the vault Inbox through obsidian-ingest before the walkthrough. Run at end of day or next morning for yesterday. Trigger keywords: evening review, nightly review, end of day, reflect on today, night review."
compatibility: Requires a vault at $OBSIDIAN_VAULT_PATH. Calendar via the Google Calendar MCP and optional email drafts via the Gmail MCP; without them the reflection still works.
allowed-tools: mcp__claude_ai_Google_Calendar__gcal__get_calendar_events mcp__claude_ai_Google_Calendar__gcal__list_calendars mcp__claude_ai_Google_Calendar__gcal__get_next_availability mcp__claude_ai_Gmail__gmail__search_email mcp__claude_ai_Gmail__gmail__get_email mcp__claude_ai_Gmail__gmail__draft_email mcp__claude_ai_Gmail__gmail__draft_reply Bash(find *) Bash(mkdir *) Skill(obsidian-ingest-inbox) AskUserQuestion question
metadata:
  version: 1.7.0
  author: eugene
---

# Skill: obsidian-nightly

**Vault:** `$OBSIDIAN_VAULT_PATH`, given in the "Vault path" section at the end of this skill. Use that value directly. Ask the user only if the section is missing.

Evening reflection workflow. Fetches the day's meetings from Google Calendar, reflects
on each one with the user, fills in the `## 🌙 Evening Review` section of the daily note,
and surfaces tomorrow's top priorities.

---

## Step 0 — Determine the target date

- If run in the evening (after 5 PM): target = **today**
- If run in the morning (before noon): target = **yesterday**
- If the user explicitly names a date, use that

Compute ISO date: `date +%Y-%m-%d` for today, `date -d yesterday +%Y-%m-%d` for yesterday.

Set `TARGET_DATE` and `TOMORROW_DATE` (= TARGET_DATE + 1 day).

---

## Step 0.5 — Inbox sweep

Meeting recorders may drop transcripts into `$OBSIDIAN_VAULT_PATH/Inbox/`. Clear it
into the vault before the meeting walkthrough below, so a same-day transcript is
already ingested by the time Step 4's "already ingested" check runs.

Invoke the `obsidian-ingest-inbox` skill (via the `Skill` tool) and let it run
to completion — it already handles listing Inbox, ingesting each file via
`obsidian-ingest`, deleting successfully-ingested files, and reporting. Fold
its one-line result ("N ingested, M left" or "Inbox is empty") into the final
summary in "Completing the skill" below.

---

## Step 1 — Read vault context

```bash
# Read the vault operating manual
Read $OBSIDIAN_VAULT_PATH/_CLAUDE.md   # if exists
```

---

## Step 2 — Load or create the target day's daily note

Path: `$OBSIDIAN_VAULT_PATH/wiki/daily/<TARGET_DATE>.md`

- If the note exists, read it.
- If not, create it from `$OBSIDIAN_VAULT_PATH/Templates/Daily Note.md` with `TARGET_DATE` substituted.

---

## Step 3 — Fetch calendar events

Use the Google Calendar MCP (both Claude Code and OpenCode):

1. `list_calendars` → the calendar with `primary: true` (its `id`).
2. `get_calendar_events` with `calendarId`, `dateMin: <TARGET_DATE>`, `dateMax: <TARGET_DATE + 1 day>`,
   `timeMin: "00:00:00"`, `timeZone` = the vault's timezone (`_CLAUDE.md` / `CRITICAL_FACTS.md`),
   else the system timezone.

The MCP returns unfiltered events. Drop working-location, focus-time, out-of-office,
birthday and Gmail-derived entries yourself.

If the MCP returns no meetings or errors, note that and continue — the user can still reflect
without calendar data.

---

## Step 4 — Walk through each meeting (one `AskUserQuestion` per meeting)

Filter the MCP events:
- Drop working-location markers (not meetings)
- Keep everything else, including personal events — the user can skip them individually

Build a list of meetings in chronological order. **Loop** over them, and for each one
first check whether it already has an ingested transcript note in the vault:

```bash
find $OBSIDIAN_VAULT_PATH/Meetings -maxdepth 1 -iname "${TARGET_DATE}*"
```

Match a result's filename (after the date) against the meeting title, case-insensitive
substring. **If a match exists, skip `AskUserQuestion` for that meeting entirely** — it
already has a properly-ingested note, richer than a quick reflection — and add a Work Log
line linking to it instead:

```markdown
- [HH:MM] <Meeting Title> — _(already ingested)_ [[Meetings/<matched filename, no extension>]]
```

Move on to the next meeting. Only meetings with no existing ingested note reach the
`AskUserQuestion` below.

Fire a single `AskUserQuestion` per remaining meeting:

```
question: "[HH:MM] <Meeting Title> — anything to capture?"
header: "Meeting note"
multiSelect: false
options:
  - label: "Skip"
    description: "Nothing notable from this meeting"
  - label: "Action item"
    description: "A follow-up for tomorrow's Focus — I'll ask you to type it next"
```

`AskUserQuestion` always appends a free-text option (rendered "Type something…") as the
**last** entry. That free-text field is where the user types a note — one step, no
decoy. **Do not** add an "Add note" / "Type your reflection below" option: it can't
capture text (the question is single-select, so a listed label and the free-text field
are mutually exclusive) and only forces the user to pick a label and then move down to
type. Typing *is* the note.

Interpret the reply:

- **Free text typed** → a **note**. Store verbatim as `{time, title, kind: "note", text}`.
- **"Skip"** (or a listed label with no text) → record nothing for this meeting.
- **"Action item"** → the user wants a follow-up but can't type it in the same
  single-select question, so fire one more `AskUserQuestion`:
  ```
  question: "[HH:MM] <Meeting Title> — what's the follow-up?"
  header: "Action item"
  multiSelect: false
  options:
    - label: "Never mind"
      description: "Don't record an action item after all"
  ```
  The free-text they type is the action. Store verbatim as
  `{time, title, kind: "action", text}` (lands in tomorrow's Focus). "Never mind" or no
  text → record nothing.

**Critical:** Do **not** guess, summarise, or paraphrase how the user felt about the
meeting, and do **not** reclassify their note as an action (or vice versa) — the option
they chose decides the kind. Record the typed text **verbatim**.

---

## Step 5 — Ask for the three Evening Review prompts

Do not synthesise these from meeting notes. Ask the user explicitly, one at a time, each
skippable. For each prompt, use `AskUserQuestion`:

```
question: "What went well today?"
options:
  - label: "Skip"
    description: "Leave this prompt blank"
```

The free-text option ("Type something…") the tool appends **last** is where the user
types their answer — same as Step 4, don't add an "Answer → type below" decoy.

Repeat for:
- "What didn't go well today?"
- "Tomorrow's #1 priority?"

The typed free text is the answer, recorded verbatim. Any "Skip" (or a listed label
with no text) → leave that field blank.

---

## Step 6 — Fill in the Evening Review section

Find `## 🌙 Evening Review` in the daily note. If it already has content beyond the
blank template, ask the user whether to **append**, **replace**, or **cancel** before
writing.

Write the three fields from Step 5 verbatim. Leave any skipped field blank — do not
fabricate content.

```markdown
## 🌙 Evening Review

**What went well:** <verbatim from Step 5, or blank if skipped>

**What didn't:** <verbatim, or blank>

**Tomorrow's #1 priority:** <verbatim, or blank>
```

Then write the per-meeting notes from Step 4 into the `## 💼 Work Log` section as
bullets, in chronological order:

```markdown
## 💼 Work Log

- [10:00] stand-up — <verbatim note>
- [10:45] Design review — <verbatim note>
- [16:30] Personal — _(skipped)_     ← omit lines for skipped meetings
```

Omit lines for skipped meetings entirely. The Work Log should only contain entries the
user chose to capture.

---

## Step 7 — Seed tomorrow's daily note

Find or create tomorrow's daily note at `$OBSIDIAN_VAULT_PATH/wiki/daily/<TOMORROW_DATE>.md`.

- If it exists: inject action items into the `## 🎯 Today's Focus` section (don't overwrite).
- If it doesn't exist: create from template, then pre-fill `## 🎯 Today's Focus` with the
  action items extracted from today's reflection. Format:

```markdown
## 🎯 Today's Focus

### 🔴 #1 — <tomorrow's #1 priority from Evening Review>

### 🟡 #2 — <first action item from meetings>

### 🟢 #3 — <second action item, if any>
```

---

## Step 7.5 — Optional: draft follow-up emails (Claude Code only, never send)

Some action items from Step 4 are really "email someone about X". If any are, **offer**
to draft them — do not draft unprompted.

> "Two of today's action items look like emails — want me to draft them for you to
> review and send? (I'll only create drafts, never send.)"

For each one the user accepts, gather recipient / subject / gist (ask if not obvious from
the action item — never invent a recipient), show the proposed draft inline, and on
confirmation create it with the Gmail MCP:

- `draft_email` (`to`, `subject`, `body_text`) for a new message, or
- `draft_reply` when following up on an existing thread (use `search_email` / `get_email`
  to locate the thread first).

**Hard rule — never send.** Create drafts only; the user reviews and sends from Gmail.
Do not call any send tool. The draft lands in Gmail Drafts.

This step needs the Gmail MCP, available in **both Claude Code and OpenCode** (the send
tool is blocked in both, so drafting is always safe). Skip silently only if the MCP is
unavailable or unauthed. Optionally note the drafted follow-ups as bullets under the Work
Log so the vault records that a draft was created.

---

## Step 8 — Vault consolidation (optional, Phase 1 only)

After filling the Evening Review, offer to run a lightweight vault close:

> "Evening review done. Want me to also close out the vault for today?
> (Moves completed kanban tasks to Done, rebuilds index.)"

If the user agrees, follow the upstream Phase 1 from
`~/.claude/skills/obsidian-second-brain/SKILL.md` (obsidian-nightly section):
- Move completed kanban tasks to Done
- Append to `log.md`: `## <TARGET_DATE> nightly | Evening review completed`

Phases 2–5 (reconcile, synthesize, heal) are intentionally deferred — they are
expensive and best run as a scheduled agent rather than interactively.

---

## Completing the skill

Return a one-line summary:
```
Evening review done for <TARGET_DATE>. Tomorrow's #1: <priority>. Action items: N. Inbox: <Step 0.5 result>.
```
