---
name: grill
description: >-
  A grilling Q&A session that refines a problem and its solution with the user until
  nothing is left assumed, then records the decisions. Works on a GitHub issue or PR,
  or on a new feature idea with no issue. Use for "grill me", "lets grill this",
  "design session", "refine the plan before we implement", or "ask me questions one
  by one". Args: an issue/PR reference or a description of the idea.
---

# grill

Interview the user until you share one understanding of the **problem** first, then
the **solution**. Nothing gets implemented in this skill.

## Before the first question

- With an issue, PR or branch: if this session hasn't grounded it yet, do the reading in the
  `ground` skill first (source, links, current code).
- With a new idea: read enough of the code and docs it touches to ask informed questions. Note
  what already exists that the idea could reuse.
- Write your current read of what the user wants in one plain sentence, and what's still missing
  from it. Open with that, so the user corrects the framing before the details.

## The design tree

Map the decisions as a tree, where each decision opens the ones that depend on it. Work through it
roughly in this order, skipping any branch that doesn't apply:

1. **Problem**: who hits it, what they see today, why it matters now, and what counts as solved.
2. **Scope**: what's in, what's explicitly out, and what can wait.
3. **Shape**: API or wire contract, data and persistence, the flow, which module or service owns
   each part. For a new idea, put a much simpler version next to the obvious one.
4. **Edges**: failure modes, concurrency, permissions, limits. Only the ones a real caller can reach.
5. **Change**: migration, compatibility, rollout, and the tests that prove it.

The **frontier** is every open decision whose prerequisites are settled. Ask the frontier, wait,
recompute, repeat.

## Asking

- Facts are your job. Look them up, or send a read-only leaf agent while you ask the questions that
  don't depend on that fact. Only decisions go to the user.
- Ask with the AskUserQuestion tool, up to four independent frontier questions per call. Ask a
  question alone when other answers hang on it.
- Each question starts with the plain framing: what's at stake in one or two sentences, no class
  names. Each option says what it changes. Put your recommendation first and mark it (Recommended).
- "Sounds good" or "whatever you think" doesn't settle a decision. Re-ask it as two concrete options.
- Push back when an answer conflicts with the code, a documented decision or an earlier answer. Say
  so plainly and ask again.
- Prefer the simplest design that is correct. Reuse what exists. Don't add machinery for far-off
  cases.

## Closing

Stop asking when you can predict the user's answer to the next three questions you'd ask. Then
restate the outcome in the user's own words — problem, solution, out of scope, what we're betting
is true — and get an explicit yes.

1. Write the decision record to `<notes-dir>/<issue-or-slug>-design.md`, outside
   any repo. Keep it to about one page:
   - **Problem**
   - **Scope and not doing**: each "not doing" with its reason
   - **Decisions**: a short bold title per decision, then the choice and its why. No D1/D2 codes;
     later notes refer to a decision by its title.
   - **Design**
   - **Bets and risks**: what we assume is true, and what would break it
   - **Work outline**: one plain line per piece of work, named for what it changes. `orchestrate`
     turns it into packages.
2. Ask where else it should go: a comment on the issue, a new issue, or straight into `/orchestrate`.
   Never post to GitHub without that answer.
