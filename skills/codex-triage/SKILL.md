---
name: codex-triage
description: >-
  Validate codex review findings on a PR, fix only the real in-scope ones, reply on
  every thread with the verdict, sync main and push. Use when the user says codex
  added review comments / findings on a PR, "validate and fix the codex comments",
  "reply to codex", or "watch for codex comments". Args: PR number or URL (default:
  the current branch's PR), plus optional --ask, --no-push, --watch.
---

# codex-triage

Codex is a second opinion, not an authority. Most of its findings are either real
defects or one of a few kinds of noise. Your job is to tell them apart with evidence,
fix the real ones minimally, and leave a reply on each one saying which it was.

## Flags

- `--ask` — show the verdict table and wait for the user's go before fixing anything.
- `--no-push` — fix and commit, but don't push or reply. Report and stop.
- `--watch` — after pushing, wait for codex's next round and triage it too.

## Verdicts

Every finding gets exactly one:

| Verdict | Meaning | Action |
|---|---|---|
| **Fix** | A real defect a real caller can hit, inside this PR's scope | Fix minimally, with a test that pins it |
| **Already handled** | Existing code or a later commit covers it | Reply with the line or sha |
| **Analysis wrong** | The claim misreads the code | Reply with the line that disproves it |
| **Far-off edge case** | Needs conditions our callers, data or trust model don't produce, or it self-heals | Reply, don't fix |
| **Unneeded guard** | A defensive check for a state that can't happen, or one already enforced upstream | Reply, don't fix |
| **By design** | Contradicts a documented decision (design/spec docs, CLAUDE.md, memory, an issue ruling) | Reply citing the decision |
| **Out of scope** | Real, but not this PR's job | Reply, and offer to file an issue |

How to decide:
- A **Fix** needs a concrete reproduction: a real production caller or input path, traced in
  code, that reaches the defect with the data codex describes, or a test that would fail today.
  If no real caller can reach it, it's not a **Fix** — "could" or "a future caller" is no reproduction.
- Read the repo's own authority (CLAUDE.md, design/spec and standards docs) before calling something a
  defect. Then read the "Settled, don't re-flag" section of the current project's memory dir
  (`MEMORY.md` index), if it has one, and any known false positives the index lists. A finding
  matching a settled entry is **By design**, citing the entry.
- Codex's P1/P2 badge is its own opinion, not evidence.
- If the fix would add more code than the harm it prevents, the verdict is not **Fix**.

## Steps

1. **Resolve the PR.** `gh pr view [<PR>] --json number,url,headRefName,state,baseRefName`.
   - If the PR is merged, ask whether to fix on a new branch off latest main or on the current branch.
   - Make sure you're on the PR's branch. If the worktree is on another branch and dirty, stop and ask.
     Settle the directory now, before any agent starts, and don't change it later.
2. **Fetch codex's items.**
   `~/.claude/skills/codex-triage/codex-items.sh <PR> [owner/repo]`
   - The script matches nothing by title or author. It prints every review thread that is still
     unresolved and has no reply (`kind: inline`), plus every review submitted with a body
     (`kind: summary`).
   - Triage every inline item. Also read the summaries, since one sometimes carries findings with no
     inline comment.
   - If there's nothing new, say so and stop (or go to step 7 with `--watch`).
3. **Validate.** Send each finding (or a tight group on the same code) to a read-only leaf agent. Use
   Sonnet for a simple one and Opus when the mechanism isn't obvious. Give it the "How to decide"
   rules and the settled-section path. Tell it to spawn no sub-agents and to write its reasoning
   first, then a verdict from the table, evidence as `file:line`, and for a **Fix** the reproduction
   and a one-line minimal fix. Check any verdict yourself if its evidence doesn't cite a line, if a
   **Fix** names no reproduction, or if it reverses codex on a mechanism that isn't obvious.
4. **Report.** Show a short table to the user: finding, verdict, one-line reason. With `--ask`, wait.
5. **Fix.** Give each **Fix** to an implementer agent (Opus or Sonnet, a leaf). It makes the minimal
   change and adds a test that pins it, following the repo's testing rules. It commits and reports,
   and runs no test suites. Then verify once, the way the repo does it: a `test-runner` agent on
   the touched test classes if the repo has one, else the repo's check command, or
   push and watch CI if the user asked for that.
6. **Ship.** Merge `origin/<base>` into the branch and push. Then reply in-thread on every root you
   triaged:
   `gh api repos/<owner/repo>/pulls/<PR>/comments/<id>/replies -f body='<reply>'`
   - **Fix**: `Fixed in <sha>. <what changed, one or two sentences>. Covered by <test>.`
   - Otherwise: `Not fixing: <verdict>. <evidence in one or two sentences, with file:line>.`
   - For findings that only appear in the summary, post one PR comment answering each.
7. **`--watch`.** Codex may review again after a push. Poll `codex-items.sh` in a background script,
   started with `run_in_background`, for up to about 20 minutes. Look for new roots created after
   your push. When they arrive, go back to step 3. Stop when a round adds nothing or reports no
   actionable findings.

Done when every codex root has a reply, every **Fix** is pushed, and the user has the verdict table.
