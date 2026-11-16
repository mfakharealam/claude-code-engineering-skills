---
name: retro
description: >-
  Look back over a Claude Code session and suggest changes to the working setup — checks,
  steering files, memory, skills, tooling — so the next session doesn't repeat its mistakes,
  worst first. Use for "retro", "retrospective", "what should we change after this session",
  or "why did that take so long". Args: optional session (default: the current one).
disable-model-invocation: true
---

# retro

Improve the setup, not the code. Find where the session lost time or went wrong, and name the
smallest change to the setup that would have prevented it. Read-only until the user picks.

## Steps

1. **Read the session.** The current conversation by default. For an older one, read its
   transcript under `~/.claude/projects/<project-dir>/*.jsonl`, picked by date and first
   prompt. Note each correction from the user, each retry, each long search, each wrong guess
   and each expensive tool call.
2. **Read the setup it ran under.** Global and repo `CLAUDE.md`, the memory index, the skills
   the session used, `.claude/settings.json` hooks, and the repo's existing checks — ArchUnit
   tests, the complexity gate, CI workflows. A check that already exists but missed the case is
   the finding, not a new one.
3. **Find candidates**, each tied to a moment in the session:
   - **Mechanical mistake** — a fixed pattern a machine could catch: a banned call, an import
     shape, a file location. Fix with a check (an ArchUnit rule, a gate rule, a hook, a CI
     step), not more prose.
   - **Judgement miss** — a review should have caught it. Fix with a rule in
     the repo's standards docs or a line in a `deep-review` lane.
   - **Navigation** — a fact took long to find. Fix with a one-line pointer where the agent
     was already looking.
   - **Steering** — an instruction that was ignored, contradicted, or changes nothing. Fix by
     rewording it, moving it to where it applies (a skill, a module `CLAUDE.md`), or deleting
     it.
   - **Information access** — something the agent couldn't see (a log, a service, a dashboard).
     Fix with a command, a doc pointer or a tool.
   - **Tool economy** — an expensive or repeated call that a script or a narrower command would
     replace.
   - **Skill gap** — a repeated multi-step workflow with no skill, or a skill step that misled.
4. **Place each fix by who reads it.** `CLAUDE.md` loads into every session, so it gets only
   pointers and always-true rules. Repo standards are for reviewers. Memory holds the user's
   preferences, per its own rules. A skill holds a workflow. Prefer a check over any of them.
5. **Report, worst first.** One line each: what happened, the change, and where it goes. Drop
   candidates that cost more than the mistake did, and anything that happened only once and
   can't recur.
6. **Apply what the user picks.** Ask with AskUserQuestion, multi-select, with your
   recommendation first. Edits to steering files replace text rather than append to it.
   Repo files go on a branch off `origin/main`, never straight to `main`.

Done when the user has a ranked list and the picked changes are made.
