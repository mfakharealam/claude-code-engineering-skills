---
name: gate
description: Pre-push gate for the current branch. If the repo has its own complexity or lint ratchet (named in its CLAUDE.md or docs), runs it against the merge-base with the PR's base and fixes or stops on blocking findings. Then runs one Opus leaf agent that reviews the branch's new code against KISS, YAGNI, DRY, single responsibility and surgical change. Each finding is fixed or waived with the user. Use for "/gate", "run the gate", "gate this before push", or when a push hook refused a HEAD that hasn't passed the gate.
allowed-tools: Bash, Read, Grep, Glob, Edit, Write, Agent, AskUserQuestion
---

# Gate

Get HEAD of the current branch through the gate before it is pushed.

The gate has two halves. **The ratchet** is the repo's own complexity or lint check, if it has one, typically blocking only findings that are new or got worse against the merge-base with the PR's base. **The principles review** is one Opus agent reading what the branch changed. A HEAD passes when every finding from both is fixed or waived by the user. If the repo marks a passing HEAD for a push hook, only its own command writes that mark — never write it by hand.

## When to invoke

- "/gate", "run the gate", "gate this before push".
- A push hook refused a HEAD that hasn't passed the gate.
- `/ship-pr` or `/orchestrate` is about to push.

## Workflow

### Step 0 — Settle the repo

Run from the worktree you will push from, and stay there — never `EnterWorktree` or `ExitWorktree` once the review agent is running.

**The base** is the branch the PR merges into: `baseRefName` from `gh pr view <branch> -R <owner>/<repo> --json state,baseRefName` when `state` is `OPEN`. Before the PR opens, a sub-PR's base is the epic its caller or the ledger names — for a sub-branch neither names, ask, never fall back to main. Otherwise it is the default branch. Every `<base>` below is that name, resolved once here.

```bash
git fetch -q origin <base>
git merge-base --is-ancestor origin/<base> HEAD || echo "behind origin/<base>"
```

- Behind `origin/<base>` → merge `origin/<base>` first, and check it builds (the repo's compile command, output to a file, read the tail). Resolve any conflict, or stop and ask if it isn't mechanical. For a sub-PR, also fetch `main`, and if `origin/<base>` doesn't contain `origin/main`, stop — main goes into the epic first, then the epic is merged here. A merge after the gate passes makes a new HEAD that needs gating again.

### Step 1 — Run the repo's ratchet, if it has one

Look for it in the repo's `CLAUDE.md` and docs: its command, how it takes a base, and how it takes a waiver. **No ratchet → say so in one line and skip to Step 2.**

The ratchet measures the working tree, so first commit anything uncommitted that is part of the work being shipped — Conventional Commits, explicit paths, never `git add -A`. Otherwise stop and tell the user what is uncommitted. Then run it against `origin/<base>`, in the background if it takes minutes, passing every waiver the user approved on this branch.

- **Passes** — note any report-only sections for the summary, but they never block. Go on.
- **Blocking findings** — show them as printed. Fix each by simplifying or deleting code, never by extracting new structure — no new classes, methods, interfaces or layers to spread the score — and commit it. Stop and ask the user when the fix isn't obvious, would reshape the design, or the finding is a false positive. A false positive is waived only by the user, through the ratchet's own waiver mechanism, and recorded as `path:line — reason` for the PR body. Then re-run.
- **Surviving mutants**, if it runs mutation testing — ask the user about each with `AskUserQuestion`, batched by class: **kill** it with an assertion that fails on it, or **waive** it as `equivalent`, `log-only` or `unreachable`. Recommend one with a line of reasoning. Commit the kills, record each waiver for the PR body, and re-run.
- **Suppression markers added** — never get past the ratchet with an in-code suppression. Remove the marker, and put the finding it hid through the waiver flow above.
- **Tool error** — report it and stop. A HEAD that hit a tool error has not passed.

### Step 2 — Principles review

The range is `git merge-base origin/<base> HEAD` to HEAD. If this session already gated the branch and no merge of the base came after, start from the sha that passed instead, so a re-gate only reviews what changed since.

```bash
git diff --shortstat <from> HEAD -- '*/src/main/*'
git diff --name-only --diff-filter=A <from> HEAD -- '*/src/main/*'
```

Use the repo's production source paths if they aren't `src/main`. **Skip the review** in either case below. Say which in one line and go to Step 3.

- **Small range** — the range adds no production file, and the `insertions` count from the shortstat above is under ~30. Deleted lines don't count, because removing code can't add complexity.
- **Already reviewed** — `deep-review` ran on this branch in this session, and every non-merge commit since it ran only fixes its findings. Its FIT axis already applied this checklist to the same range.

Otherwise launch **one** `general-purpose` agent with `model: "opus"`. Give it:

- **The range:** review `git diff <from> HEAD` only — paste the resolved sha, not the variable.
- **The scope:** production code in the range, plus anything else in it that adds an abstraction — a new interface, base class, helper, config knob or indirection.
- **The checklist:**
  - KISS, YAGNI (no speculative flexibility), DRY without premature abstraction, single responsibility, surgical change.
  - The repo's own coding rules, if its `CLAUDE.md` has them. Tell the agent to read them there.
  - Fit to problem, both directions. Hacks: band-aids, shortcuts, special-cases that paper over a root cause, a new convention invented to prop up a hack, dead-end error handling that hides a real failure. Overbuild: speculative flexibility, single-use abstractions, indirection that buys nothing, 200 lines that should be 50. Also the inverse — simplicity used as an excuse to cut a corner.
- **Five checks to run explicitly** — a lint tool can't see them, and they are how a ratchet gets gamed:
  - A new type, helper or indirection with one caller.
  - An extraction that lowers a score without removing code. The fix for complexity is less code, not more pieces.
  - Handling for a state no caller reaches.
  - Hand-copied fields where the repo has a mapper convention, or a re-implemented helper where one already exists — search the codebase before accepting a new one.
  - Orphans: a new or newly-public type, method or constructor, or widened visibility, in production code whose only callers are tests or which has no caller at all. Find callers by searching production code only, and report each orphan as `file:line` with its only callers.
- **The rules:**
  - Flag only what the range introduced. Code that was already there is not a finding, even when it breaks the checklist.
  - At most 5 findings, most important first. "None" is a valid answer — never pad the list.
  - Each finding: `file:line`, the principle, a caller trace that shows it is real, and the lines to delete or simplify.
  - Don't re-litigate a deliberate design decision recorded in the repo's docs.
  - Return read-only analysis as text. Make no edits. **Spawn no sub-agents.**

### Step 3 — Settle every finding

Check each finding against the code yourself, once. Drop any that don't hold up, with a one-line note saying why. Present the rest as one numbered list, most important first.

Each finding ends as **fixed** or **waived**:

- **Fixed** — make the change and commit it.
- **Waived** — only by the user. Ask with `AskUserQuestion`: one or two lines of context, your recommended option first. Batch related findings into one question where you can.

If anything changed, re-run Step 1 on the new HEAD — the ratchet only. The fix delta gets no second review.

### Step 4 — Verdict

Push in a separate Bash call, so a push hook sees the final HEAD. End with a short verdict:

- blocking findings and surviving mutants from the last ratchet run (0), or "no ratchet"
- ratchet waivers, each `path:line — disposition or reason` — these go in the PR body
- review findings: fixed / waived / dropped, and which were waived — or why the review didn't run (small range, already reviewed)
- the gated sha

## Constraints

- **Passed means passed.** Never call a HEAD gated, or run the repo's mark-as-passed command, after a failure or with a finding still open.
- **One review agent, Opus, leaf.** `model: "opus"`, never `subagent_type: "fork"` — a fork ignores the model and runs on the session model. No sub-agents, and no second review of a fix.
- **Fixes are commits.** Every fix is committed before the re-run, so the gated sha is what gets pushed.
- **Waivers are the user's.** Never waive a finding or a survivor on your own judgment, and never through an in-code suppression marker.
- **Never bypass a push hook to get past a failing gate** unless the user says so.
