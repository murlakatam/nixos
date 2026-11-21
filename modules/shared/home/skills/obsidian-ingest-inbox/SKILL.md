---
name: obsidian-ingest-inbox
description: "Sweep the vault's Inbox and run the obsidian-ingest skill over every file found there, e.g. meeting transcripts or anything placed there manually. Deletes each file from Inbox once it has been successfully ingested (the vault keeps its own permanent raw/ copy). Can be run standalone or by obsidian-nightly. Trigger: 'ingest inbox', 'process inbox', '/obsidian-ingest-inbox'."
compatibility: Designed for Claude Code and OpenCode
allowed-tools: Bash(find *) Skill(ingest)
metadata:
  version: 1.0.1
  author: eugene
---

# Skill: obsidian-ingest-inbox

**Vault:** `$OBSIDIAN_VAULT_PATH`, given in the "Vault path" section at the end of this skill. Use that value directly. Ask the user only if the section is missing.

Sweeps `$OBSIDIAN_VAULT_PATH/Inbox/` and runs `obsidian-ingest` (via the `ingest`
alias) over every file found there — e.g. meeting transcripts, or anything else
the user places there manually.

## Step 1 — List Inbox contents

```bash
find $OBSIDIAN_VAULT_PATH/Inbox -maxdepth 1 -type f
```

If empty, report "Inbox is empty — nothing to ingest" and stop.

## Step 2 — Ingest each file, one at a time

Process files oldest-first (so ingestion order matches recording order).
Sequentially, not in parallel — `obsidian-ingest` rewrites shared vault state
(entity pages, `index.md`), and running multiple ingests concurrently risks
one overwriting another's changes.

For each file:

1. Invoke the `ingest` skill with that file's absolute path as the argument.
2. Only after `obsidian-ingest` completes successfully for that file, delete
   it from Inbox (`rm <file>`) — the vault already keeps its own permanent
   copy under `raw/` (transcripts/articles/etc, per `obsidian-ingest`'s own
   classification), so the Inbox copy is now redundant.
3. If a file fails to ingest, **leave it in Inbox** and note the failure —
   never delete a file you're not sure was actually ingested.

## Step 3 — Report

One line per file: `<filename> → ingested (N created, M rewritten)` or
`<filename> → failed: <reason>`, then a final summary line: `Inbox: N
ingested, M left`.

## Notes

- This skill only processes files already sitting in Inbox — it doesn't fetch
  anything itself (no calendar, no email, no recording).
- Safe to run against an empty Inbox — reports and exits immediately.
- Also called by `obsidian-nightly`, which folds the result into its summary.
