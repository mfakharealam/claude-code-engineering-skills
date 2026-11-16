---
name: day-update
description: Build the day's work update from git, GitHub activity and Claude Code session transcripts across every repo, then append it to ~/updates.txt. Use when the user asks "what did I work on today", wants their daily update / standup notes / worklog entry, or invokes /day-update. Takes an optional date (YYYY-MM-DD, "yesterday") — defaults to today.
---

# Day update

Reconstruct one day of work across all repos and all Claude Code projects, and record it in `~/updates.txt`.

## 1. Collect

```bash
bash ~/.claude/skills/day-update/collect.sh [YYYY-MM-DD]
```

Four sections come back:

- **GIT** — commits authored that day across `$REPOS_DIR` (default `~/code`), all branches, worktrees included.
- **GITHUB ACTIVITY** — pushes, PR opens/merges, reviews, issue events, as counts.
- **PRs / ISSUES TOUCHED** — numbers, titles and state.
- **SESSION PROMPTS** — the user's own prompts from every session that day, with time and cwd. This is the only source for work that left no commit: research, debugging, questions answered, support, dead ends.

If a section is empty, say so rather than inventing filler.

## 2. Synthesize

Group by repo/project. Derive the repo from the commit's repo name or the prompt's cwd (a `.claude/worktrees/...` path and a `<repo>-<n>` sibling directory both belong to the parent repo).

- One bullet per real unit of work, not per commit. Several commits on one branch are one bullet.
- Name the outcome, not the activity: "fixed X", "landed Y", not "worked on Y".
- Mention branch, PR or issue number when it sharpens the line; skip it otherwise.
- Sustained research or debugging that produced no commit still earns a bullet — that is the point of the transcript source.
- Match the terseness already in `~/updates.txt`: fragments, lowercase, no trailing periods.
- Last group, only when it does not fit a repo: `misc` — tooling, environment, cross-cutting research.

## 3. Write

`~/updates.txt` holds the **current week only**, week starting Sunday.

Before appending, read the file and check the newest `Mon DD` header:

- Same week as the target day → append (or merge into that day's block if it already exists — never duplicate a date).
- Earlier week → move the whole current content to `~/updates-prev.txt` (overwriting it), truncate `~/updates.txt`, then write the new day as the first entry.

Format, exactly as the file already uses — tab-indented bullets, two tabs and `--` for sub-bullets, blank line between days:

```
Sep 22
	- backend
		-- fixed pagination in the orders list, PR merged
		-- retry on upstream timeout, PR open
	- frontend
		-- empty state for the search page
	- misc
		-- CI: cached dependencies between jobs
```

Collapse to flat bullets under the date when the whole day sits in one repo. Keep days in date order.

**Write the file without asking and without showing a draft first.** No confirmation, no preamble. Once written, print the entry and nothing else.
