---
name: handover
description: >-
  Write a handover note so a fresh session can resume this work cold, plus a short
  paste-ready prompt for it. Use for "give me a handover prompt", "note down the
  remaining work", "write a handover", or before ending a long session. Args: optional
  topic or issue number.
---

# handover

The next agent knows nothing about this session. The note must be enough on its own.

## Steps

1. **Check state.** Run `git status`, `git log --oneline origin/main..HEAD`, check whether the branch
   is pushed, look up its PR (`gh pr list --head <branch>`), and note the worktree path. If there's
   uncommitted work, ask whether to commit it first.
2. **Write the note** to `<notes-dir>/handovers/<issue>-<slug>.md`. It lives
   outside the repo on purpose, because it's a note between sessions, not a doc. Use these sections:
   - **Prompt for the next agent**: a fenced block, at most about 15 lines. It names the
     issue/PR, says "read this note first", gives the exact worktree and branch, says not to create
     another branch or worktree, and lists the next steps in order. It ends with what to ask the
     user before doing anything outward-facing.
   - **Where things stand**: branch, last commit, pushed or not, PR, sync with main.
   - **Done**: each item with its commit sha.
   - **Remaining**: a checklist in order, each item small and checkable, and each citing its source (an issue or comment URL, or a ledger line).
   - **Decisions**: what the user settled this session and why, plus options rejected. The next
     agent must not reopen these.
   - **Gotchas**: traps hit this session and how to avoid them.
   - **How to verify**: the commands and the live checks that prove it works.
   - **Open questions** for the user.
   Point to existing ledgers, design notes and issues by path or URL rather than copying them.
   Before saving, strike hedges on known facts, metadiscourse ("Below is…"), zombie nouns
   ("make a decision" → "decide"), precautions that don't change the next step, and officialese
   ("utilize", "in order to", "prior to").
3. **Reply** with the note's path and the prompt block only.

Done when someone with only the prompt and the note could finish the work without asking what
happened in this session.
