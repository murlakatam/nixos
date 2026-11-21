---
name: interview
description: "Router for interview-style skills that question the user until an idea converges. MUST USE when the user says 'interview me', 'brainstorm with me', 'grill me on this', 'help me think this through', 'deep interview', or '/interview'. Asks which underlying skill to run (obsidian-brainstorm, oh-my-claudecode:deep-interview, oh-my-claudecode:plan) after explaining how they differ, then hands off."
compatibility: Designed for Claude Code. OpenCode has only obsidian-brainstorm.
metadata:
  version: 1.0.0
---

# Skill: interview

Three skills each interview the user one question at a time. They differ in what they produce and where it lands. This skill picks one with the user, then hands off.

## The options

| Skill | Produces | Lands in | Use for |
|---|---|---|---|
| `obsidian-brainstorm` | A design note with 2–3 named approaches and one recommendation | `~/docs/ai-brain` (ideas folder, linked from today's daily note) | Personal or non-repo ideas, where past vault decisions matter. Stops once 5 of 6 checks pass: problem, constraints, trade-off, scope, prior decisions, anti-goals. |
| `oh-my-claudecode:deep-interview` | A build spec, gated on a scored ambiguity threshold | `.omc/specs/deep-interview-<slug>.md` in the current repo | A vague coding task you mean to build next. Feeds `omc-plan`, then waits for your approval before anything executes. |
| `oh-my-claudecode:plan` | A work plan, with an interview first if the request is broad | `.omc/plans/` in the current repo | A coding task you can already describe, where you want steps more than requirements discovery. |

## Steps

> Offer only the targets that appear in your available skills. If just one is available, use it and say so. If none is, tell the user which skill or plugin is missing.

1. If the user already named one of the three, skip to step 4.
2. Take the topic from the arguments, or from the recent conversation.
3. Ask with `AskUserQuestion`: one question, one option per row above. Each option's description states what it produces and where it lands. Mark one option "(Recommended)" by these rules:
   - Inside a git repo and the topic is code to build: `deep-interview`.
   - Inside a git repo and the topic is already specific: `plan`.
   - Otherwise: `obsidian-brainstorm`.
4. Invoke the chosen skill with the `Skill` tool and pass the topic as its arguments. Follow that skill from then on.
