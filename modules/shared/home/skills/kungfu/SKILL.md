---
name: kungfu
description: "Call-graph and history queries over the current repo with the kungfu CLI. Use when asking what calls or is called by a symbol, what breaks if something changes, which modules are coupled, why code is the way it is (symbol/file history), where a concept lives with no name to grep for, a symbol's full body plus contracts, or a large file's outline. Not for literal-string or known-path lookups: use grep."
compatibility: Designed for Claude Code.
metadata:
  version: 1.0.0
---

# kungfu: call-graph and history queries

kungfu indexes this repo's symbols, call graph, and git history. Use it
for the questions grep cannot answer. Use grep for the ones it can.

Invoke kungfu through Bash (`kungfu <subcommand> --help` for flags):

| Question | Call |
|---|---|
| What calls this? What does it call? | `callers` / `callees` |
| What breaks if I change this? | `affected`, then `smart-test` |
| Which modules are entangled? | `coupling` |
| Why is it like this? What changed? | `symbol-history` / `file-history` / `change-timeline` |
| Where does a concept live, with no name to grep for? | `search --semantic` |
| Full body of a symbol plus its contracts | `edit-context` (no follow-up Read) |
| Shape of a file over 50 lines | `file-outline`, then a targeted Read of that range |
| No idea where to start | `ask-context "<task>" --budget tiny` |

Grep remains correct for a literal string, a known path, or a one-off
match. Do not route those through kungfu.

Run `kungfu memory search "<topic>"` before implementing — it holds
decisions and warnings recorded during earlier work. `kungfu memory
add ...` records a new one; pin sparingly.

A PostToolUse hook reindexes every edited file, so never call `index`
by hand.

If kungfu returns empty ("No callers found", "No affected symbols", no
search hits) for a query you expect to hit, fall back to grep — an empty
result is not proof of absence. Two known blind spots: the call graph
omits same-file calls, so `callers` and `affected` miss them; non-Python
parsing (TSX especially) can misparse or return unrelated
cross-language hits.
