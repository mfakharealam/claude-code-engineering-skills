---
name: cleanup
description: >-
  After PRs merge, remove their worktrees and branches and bring the main checkout to
  latest main. Use for "clean up", "delete the merged worktrees", "remove the worktree and
  branch", "switch to main and pull". Args: one or more PR numbers or branch names, or
  none to sweep every merged branch.
---

# cleanup

Never destroy unmerged or unpushed work. When unsure, stop and ask.

## Steps

1. **List the targets.** From the args. With none, run `git worktree list` and `git branch --merged origin/main`
   and propose the set. Some of those may still be in use, so confirm the list before removing
   anything the args did not name.
2. **Confirm each is merged.** `gh pr view <n> --json state,mergedAt,headRefName`. A branch with no PR
   counts as merged only if `git merge-base --is-ancestor <branch> origin/main` says so. If not merged,
   skip it and say why.
3. **Check each worktree for loose work.**
   - `git -C <wt> status --short` for uncommitted changes.
   - `git -C <wt> log --oneline @{u}..` for unpushed commits. A squash-merged PR shows these too, so
     compare against the merged PR's head sha before worrying.
   - If any real work is left, stop and ask. Show it and offer options: keep it, save it to a branch,
     or discard.
4. **Remove.** For each clear target:
   - `git worktree remove <wt>`. If that refuses because of changes, stop and ask. Do not add `--force`.
   - Also `git worktree remove` each worktree under the repo's `.claude/worktrees/` (leftover agent
     worktrees) where `git -C <wt> status --short` and `git -C <wt> log --oneline origin/main..HEAD` both print nothing. Report and leave any other, never `--force`.
   - `git branch -d <branch>`. If it refuses on a squash-merged branch whose PR is confirmed merged
     and whose worktree had nothing loose, `-D` is fine. Otherwise ask.
   - Remote: `git ls-remote --heads origin <branch>`. If it is still there, `git push origin --delete <branch>`.
5. **Update the main checkout.** In the main worktree, `git switch main`, `git pull origin main`
   (a stash or dirty tree means stop and ask), then `git worktree prune` and `git fetch --prune`.
   If asked to move a different branch into the main worktree, do that instead of switching to main.
6. **Report.** One line per target: removed, skipped (with the reason), or waiting on the user. End
   with the main checkout's branch and head.

Done when every merged target is gone, nothing unmerged was touched, and main is current.
