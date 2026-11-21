---
name: tuicr-review
description: "Generic tuicr review helper. Opens any markdown content as a diff in tuicr for inline commenting, reads back the comments, and returns them raw to the caller. Building block for obsidian-priority-list and sync-all-brains. Also invokable directly to review any ad-hoc content."
compatibility: Designed for Claude Code and OpenCode
allowed-tools: Bash(tuicr-wrapper *) Bash(tuicr review *) Bash(git init *) Bash(git add *) Bash(git commit *) Bash(git config *) Bash(mkdir /tmp/tuicr-review-*) Bash(pgrep -x tuicr)
metadata:
  version: 1.3.0
---

# Skill: tuicr-review

Generic tuicr review step. Takes any content, shows it as a git diff in tuicr
for inline commenting, reads back the comments, and returns them to the caller.

**This skill does not interpret comments** — that's the caller's job. It knows
nothing about items, IDs, or what the content means.

Used as a building block by **obsidian-priority-list** and **sync-all-brains**.
Can also be invoked directly to review any ad-hoc markdown content.

---

## Interface

**Caller provides (before delegating here) — one of two shapes:**

- **Single file:** `content` (the markdown string to display) + `filename`
  (what to call it in the diff, e.g. `priority-list.md`; defaults to `review.md`).
- **Multiple files** — `files`: a list of `{filename, content}` pairs. Use
  this whenever the content is really several independent items (e.g. queue
  candidates) — each becomes its own file in the diff, so the user reviews
  them as separate files in tuicr's file tree instead of one concatenated
  blob. Pick distinct, descriptive filenames; they're what the user sees.

Always also provide `guidance` — instructions to print before launching tuicr
(caller writes this; it should explain what comments do in that context).

**This skill returns:**

- Raw `tuicr review comments` JSON. Each comment carries a `path` field naming
  the file it was left on. **Multi-file callers map comments back to items by
  `path`** — `start_line` is only meaningful within a single file. Single-file
  callers may still use `start_line` as before.
- Or: verbal feedback string if the user adds it via the fallback prompt
- Or: `null` if the user explicitly skips

`comment_type` is passed through unchanged; callers may ignore it.

---

## Step 1 — Write to a temp git repo as a diff

```bash
REPO_DIR="/tmp/tuicr-review-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$REPO_DIR"
cd "$REPO_DIR"
git init -q
git config user.email "claude@local"
git config user.name "Claude"

# Empty base commit (no files at all) — every file in the next commit shows
# up as a full addition. Works identically for one file or many.
git commit -q --allow-empty -m "base"
```

Write every file to review (one for single-file callers, one per entry in
`files` for multi-file callers):

```bash
cat > "<filename>" << 'CONTENT_EOF'
<content>
CONTENT_EOF
```

Then stage and commit all of them together, so tuicr shows every file in one
diff review session:

```bash
git add -A
git commit -q -m "Review: $(date +%Y-%m-%d)"
```

---

## Step 2 — Print guidance and launch tuicr

Print the caller-supplied `guidance` text verbatim so the user knows how to
comment for this specific review context.

### Check for an open review first

Never open a second tuicr over a review the user has open. Check before launching:

```bash
pgrep -x tuicr
```

If it prints a PID, a review is open. Do not launch, do not kill it. Wait and
retry, using `CronCreate` with `recurring: false`. The repo from Step 1 stays
in place, so each retry re-runs only this step.

| Attempt | Wait before retry |
|---|---|
| 1 | 1 minute |
| 2 | 2 minutes |
| 3 | 4 minutes |
| 4 | 8 minutes |
| 5 | 16 minutes |

1. Tell the user once: "A tuicr review is open. I will retry in N minutes."
2. Schedule a one-shot cron for now + the wait. The prompt names `REPO_DIR`, the attempt number, and says to re-run the "Check for an open review first" step.
3. End the turn. The cron prompt resumes the skill.
4. On each retry, if `pgrep -x tuicr` is empty, launch tuicr and continue at Step 3.
5. If tuicr is still open after attempt 5, stop. Tell the user the review is not shown, give `REPO_DIR`, and return `null`.

If `CronCreate` is unavailable (OpenCode), run `sleep <seconds>` in Bash for each wait instead.

If `pgrep` prints nothing, launch:

```bash
tuicr-wrapper "$REPO_DIR" HEAD~1..HEAD
```

Set `timeout: 600000` on the Bash call. Always set `dangerouslyDisableSandbox: true`
too — `tuicr-wrapper`'s `sandbox.excludedCommands` entry does not reliably stop
bwrap's network-namespace loopback setup from failing on this host (see the
`tuicr` skill's notes). Wait for tuicr to exit.

If `tuicr-wrapper` exits with code 3, the user closed the popup without
pressing q, so the review did not finish. Still run Step 3 to read the
comments saved so far, and tell the caller the review was closed unfinished.
Never pass an unfinished review to the caller as "no comments".

---

## Step 3 — Read comments

```bash
SESSION=$(tuicr review list --repo "$REPO_DIR" | jq -r 'sort_by(.updated_at) | last | .slug')
tuicr review comments --repo "$REPO_DIR" --session "$SESSION"
```

Return the raw JSON to the caller. The caller resolves `start_line` → item
using its own map.

---

## Fallback — no comments (including empty sessions)

If `tuicr review list` returns `[]`, or the session exists but has zero
comments, **do not silently return empty**. Use `AskUserQuestion` with:

- **Add verbal feedback** — user types it; collect and return as a string
- **Skip this review** — nothing to do; return `null`

Return whichever the user chose. Never silently leave a caller with no signal.

---

## Notes

- Temp dir at `/tmp/` is ephemeral — leave it for the OS to clean up
- This skill does not interpret, filter, or act on comments in any way
- The caller is responsible for the `line → item` map and all post-review logic
