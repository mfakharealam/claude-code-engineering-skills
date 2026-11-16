---
name: recap
description: >-
  Tell the user in chat where the work stands, from the real state and not from memory of
  the conversation. Use for "where were we", "what's left", "what have we fixed", "give me
  an overall report", "one line each", "confirm me the issue again", or after a crash.
  Args: optional topic, issue or PR number.
---

# recap

An answer in chat. It differs from `handover`, which writes a file for a fresh session.

## Steps

1. **Read the state.** Do not trust the conversation alone.
   - `git status`, `git log --oneline origin/main..HEAD`, and `git worktree list`.
   - The PR: `gh pr list --head <branch>`, then `gh pr view` and `gh pr checks`. Note unresolved
     review threads.
   - The issue, if named: `gh issue view <n> --comments`.
   - The ledger or handover for this work, in `<notes-dir>` (`ls -t` and match
     on the topic). Read it if one exists.
   - After a crash, also look at the branch's recent commits and any uncommitted diff.
2. **Sort into four groups.**
   - Done: merged or committed and pushed.
   - In progress: uncommitted work, or a PR with CI or review still running.
   - Left: not started.
   - Blocked on the user: decisions, merges, approvals.
3. **Answer.** One plain line per item, under the group it belongs to. Skip an empty group.
   - No code, no file paths, no function names, no internal labels. Say what changed for the
     platform or the user. Use the platform's own words.
   - Use issue and PR numbers only as links to find it again.
   - For "confirm the issue", give two lines: what goes wrong, and who it hits.
   - Lead with the verdict if there is one ("two PRs merged, one left").
4. **Flag mismatches.** If the ledger and the git state disagree, say so in one line and trust git.

Done when every item is one plain line, grounded in something you read this run.
