---
name: gauntlet-loop
description: "Run a Gauntlet Loop: a lead agent splits a goal into pieces, a builder subagent works each piece, and a separate harsh critic subagent with fresh context compares the real output against a concrete reference bar, looping until the critic is satisfied or the budget runs out. Use for open-ended quality-driven builds (UI, visuals, docs, demos) where a reference example exists. Trigger: 'gauntlet loop', '/gauntlet-loop', 'loop until it matches X'."
argument-hint: "<goal> [bar: reference example, screenshot, URL or file]"
metadata:
  version: 1.0.0
  source: https://somethingbig.ai/gauntlet-loop (Matt Shumer), https://github.com/mshumer/Claude-of-Duty
---

# Gauntlet Loop

You are the lead agent. You own the goal and the loop. You never build and
never judge a piece yourself; subagents do both.

## 1 — Fix the goal and the bar

- State the goal as an outcome, not an implementation. Let builders pick the route.
- Get a concrete bar: a real example of "great" (screenshots, a URL, a file, a
  shipped product). If the user gave none, ask for one. A vague bar ("make it
  good") gives a vague critic.
- Decide how a critic sees real output: render it, screenshot it, run it,
  read the file. If output is visual, make captures reproducible (fresh page or
  process per capture, fixed inputs), or critics compare noise.

## 2 — Split the goal

Break the goal into the smallest pieces that can improve separately. Give each
piece one owner.

If pieces are coupled (one changes what another looks like or assumes), give
the coupled set a single owner and run it sequentially. In the source
experiment, parallel owners of coupled systems kept breaking each other and
raised defects; one owner per coupled concern doubled the gain.

Write a short contract file if more than one builder touches shared
interfaces: ownership per directory and the shared types or events.

## 3 — Loop each piece

For each piece, repeat:

1. **Build.** Spawn a builder subagent with the goal, the bar, its piece, the
   contract and the latest critique. It changes the work and produces fresh
   output for the critic.
2. **Critique.** Spawn a new critic subagent. Give it only the bar, the output,
   and the scoring rubric. Never give it the builder's history, reasoning or
   excuses. Tell it to be harsh, compare blind A/B against the bar where
   possible (which is better, and why), score 0-10, and list concrete defects
   ranked by impact.
3. **Decide.** If the critic says the output matches the bar, the piece is
   done. Otherwise feed the defects to the next build round.

Do not fix a round count. Loop until the critic is satisfied, scores stop
moving for two rounds, or the user's budget runs out. Use `/loop` or a workflow
if the user asked for long autonomous runs.

Builders can contradict a critique when measurement shows the critic misread
the cause. Require them to show the measurement.

## 4 — Report

Report per piece: final score, score per round, what still falls short of the
bar, and any root cause left unfixed. State plainly if the result does not
match the bar.
