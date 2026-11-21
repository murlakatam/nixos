---
name: research-router
description: "Router for deep research. MUST USE when the user says 'deep research', 'research this deeply', 'do some research on', or '/research-router'. Picks the research skill from where the session is: a code repo goes to oh-my-claudecode:research, an Obsidian vault goes to obsidian-research-deep, anything else goes to anthropic-skills:deep-research. Asks only when the location and the topic disagree."
compatibility: Designed for Claude Code.
metadata:
  version: 1.0.0
---

# Skill: research-router

Three skills do deep research, each against a different body of knowledge. This skill picks one from the working directory and the topic, then hands off.

## The options

| Skill | Researches | Writes |
|---|---|---|
| `oh-my-claudecode:research` | The current repo first (files, symbols, callers, git history), then official docs | Findings in the chat, each cited to file and line. Nothing on disk. |
| `obsidian-research-deep` | What the vault already knows, then fresh web sources for the gaps | A delta report in `Research/Deep/`, plus proposed fixes to stale vault notes. It confirms before changing an existing note. |
| `anthropic-skills:deep-research` | The open web | A cited report in the chat. Nothing in the vault. |

## Steps

> Offer only the targets that appear in your available skills. If just one is available, use it and say so. If none is, tell the user which skill or plugin is missing.

1. Take the topic from the arguments, or from the recent conversation.
2. Pick the target from the working directory:
   - If the working directory is under `~/docs/ai-brain` or `~/docs/brain`: `obsidian-research-deep`.
   - If the working directory is inside a git repo: `oh-my-claudecode:research`.
   - Otherwise: `anthropic-skills:deep-research`.
3. If the topic contradicts that pick, ask with `AskUserQuestion` instead of guessing. One option per row of the table, the step-2 pick first and marked "(Recommended)". Contradictions:
   - In a code repo, the topic is about the outside world (a vendor, a market, a library choice) and not this code.
   - In a code repo or anywhere else, the user mentions the vault, their notes, or updating what they know.
   - In the vault, the topic is about a code repo.
4. Say in one line which skill you picked and why. Invoke it with the `Skill` tool and pass the topic as its arguments. Follow that skill from then on.
