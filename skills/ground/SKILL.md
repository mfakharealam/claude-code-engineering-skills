---
name: ground
description: >-
  Understand the problem behind a change before any work starts, then the approach. Starts
  from anything — a GitHub issue, PR, branch or a plain description — and looks well past
  it. Pins the problem down with the user first, then gives a high-level view of how it
  would be solved. Read-only. Use for "ground yourself in", "go through this issue", "what
  is this issue asking", "is this still valid / can it be closed", or before implementing
  an issue or PR. Args: issue or PR URL/number, branch name, or a short description.
---

# ground

Understand before acting. The problem comes first and gets pinned down with the user before
any talk of a solution. The user works at a high level, so speak in needs, behaviour and
approach, not code. No branch, no edits.

For wide reading in either phase, run parallel read-only leaf agents — Sonnet, or Opus for
tangled flows — tell each to spawn no sub-agents, and keep only their conclusions.

## Phase 1 — the problem

1. **Read the source.** Whatever was given is a starting point, not the boundary.
   - Issue: `gh issue view <n> -R <repo> --comments` and its timeline
     (`gh api repos/<repo>/issues/<n>/timeline`)
   - PR: `gh pr view <n> --comments`, `gh pr diff <n> --name-only`, and the review threads
     (`gh api repos/<repo>/pulls/<n>/comments`)
   - Branch: `git log --oneline origin/main..<branch>`, `git diff --stat origin/main...<branch>`,
     and its PR if it has one
   - Free text: treat it as the problem statement. If it points at an existing issue or PR,
     find it and confirm the match with the user when it's ambiguous.
2. **Look wider than the links.**
   - Linked issues and PRs, one hop out, sibling repos included.
   - Related issues and PRs nobody linked, open and closed, in this repo and every neighbour:
     duplicates, earlier attempts, partial fixes, workarounds, asks that shape the design.
     Run one `gh search issues` and one `gh search prs` per repo, with the symptom, feature and
     class terms OR-joined in one query as separate arguments, a phrase quoted on its own
     (`-R <org>/<repo> "missing names" OR slow OR OrderService`), never the whole query in one
     quoted string, and no `--state` filter, so one call covers open and closed.
   - History of the area: `git log` and blame on the code involved — why it is shaped this way.
   - Settled decisions: the memory index, the design records, ledgers and handovers in
     `<notes-dir>`, and earlier design or grilling comments on the thread.
     Carry them forward, don't reopen them. Find notes with
     `grep -l -i '<term>' <notes-dir>/*.md <notes-dir>/handovers/*.md`,
     never by listing the folder.
   - Intent: the repo's docs for the area — what it is *for* there.
   - Neighbouring repos: the other repos built on this one or beside it. Check whether the problem
     comes from one of them, shows up in one, or would change what they rely on. Read their
     latest `origin/main` — local checkouts under `<repos-dir>` after a
     fetch, through `gh` where there is none.
3. **Dissect it from first principles.** Set the proposed fix aside. Pull the ask apart:
   - who is affected, and what they are trying to do
   - what they see today, and what goes wrong or is missing for them
   - the symptom, the real need under it, and the solution the issue suggests — three
     different things
   - why it matters to them or to the project, and why now
   - what must be true for it to count as solved
   - whether it is one problem or several bundled together

   Fetch origin and confirm on latest main whether the problem still happens today.
4. **Share the problem and stop.** Short enough to read in one glance — about ten lines, no
   code, one line per item, and drop any item with nothing to say:
   - **Need**: who needs what, and why it matters.
   - **Problem**: what's broken or missing from their side, in one or two sentences.
   - **Solved when**: what the user would see once it's fixed.
   - **Still real?**: yes, no or partly. If already solved, name the PR that did it.
   - **Related**: only what changes the picture — a duplicate, a settled decision, an earlier
     attempt. At most three.
   - **Neighbours**: only repos it actually touches.
   - **Unclear**: each question the user's reading must settle, with your best guess and why.

   Keep the rest of the reading — evidence, history, the full related list — back. End with one
   line offering it, ask the user to confirm or correct the problem, and end the turn.
5. **Refine it with the user.** Fold each correction in, re-read what it changes, and restate
   the problem. If it is several problems, say so and agree which one this is. Repeat until the
   user explicitly confirms it — "sounds good" or silence isn't a confirmation, so ask what they
   would change. Don't move to the approach until the problem is pinned down.

## Phase 2 — the approach

Only once the user has confirmed the problem.

6. **Work out the approach.** Read whatever code it takes to be sure, and reuse what exists.
   Start from the smallest change that meets **Solved when**. Anything bigger is an option.
7. **Sweep before settling on it.** Run parallel read-only agents, and never skip this to move
   faster:
   - **Same pattern elsewhere.** Find every other place with the same symptom or shape, and say
     whether the site in hand is the outlier or the norm.
   - **Governing convention.** Find any deliberate rule the change touches — migration and code
     comments, standards docs, sibling code. The fix conforms to it; it never overrides it to
     cure an outlier.
   - **Spike when the cause is inferred.** Measure or prototype until the cause is confirmed and
     the fix is shown to move it.

   Shape the approach from that whole picture.
8. **Report the approach at a high level.** Same budget — about ten lines, drop empty items:
   - **Approach**: three to five steps — what changes for whom, which modules or areas it
     touches, and which steps are risky. Simplest version first, bigger options after.
   - **Assumes**: what the approach bets is true and hasn't been checked.
   - **Sweep**: outlier or norm, the convention it follows, and other sites with the same issue.
   - **Neighbours**: what an affected neighbouring repo would need to change.
   - **Out of scope**: one line.
   - **Open decisions**: only what the user must decide, put through AskUserQuestion with your
     recommendation first.

   No code, no class-by-class walk-through, no `file:line` lists unless the user asks — they
   read the code in the PR.
9. **Stop.** Offer the next step: `/grill` for the open decisions, or `/orchestrate` to build it.

Done when the user has confirmed the problem and has a high-level approach they can decide on.
