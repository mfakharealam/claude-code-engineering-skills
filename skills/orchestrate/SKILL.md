---
name: orchestrate
description: >-
  Build a change end to end as the lead. Plan, coordinate and review while subagents
  do all the implementation, then run a review, open the PR and post the findings.
  Use for "orchestrate", "use subagents / delegate the work", "plan, coordinate and
  review", or "implement this issue". Args: an issue/PR reference or a task
  description, plus optional --here, --no-review, --review=<skill>, --no-pr.
---

# orchestrate

You are the lead. You plan, hand out work, check it and integrate it. Subagents do the
reading-heavy and editing work. Your context is the scarce resource, so keep file dumps
and build output in the agents.

## Flags

- `--here` — use the current branch and worktree instead of cutting a new one.
- `--no-review` — skip step 7.
- `--review=<skill>` — the review to run in step 7. The default is `deep-review medium`.
  Use `code-review medium` in repos without design/spec or standards docs.
- `--no-pr` — stop after step 7 with the commits on the branch.

## Agent rules

These go into every agent prompt.

- **Model.** Opus for complex or cross-cutting work, Sonnet for simple or mechanical work and for
  reviews of mechanical work. Haiku only for searching. Pass `model` explicitly.
- **Leaf.** Say "spawn no sub-agents" in every prompt.
- **Small.** One package or one finding per agent, about 20–30 minutes of work: at most 5 to-do
  items, one line each, touching about 5 files or fewer.
- **Implementers** follow the shared rules file, if there is one (e.g. `<notes-dir>/<repo>-implementer-rules.md`):
  read the docs for their area, edit only the files they own, commit, and report each item done or
  not, decisions, the sha, and anything noticed outside their files but not touched. They don't run
  test suites and they don't push.
- **Parallel** at most 3 agents, and only when owned files don't overlap. Implementers that build in
  parallel need separate worktrees.
- **Shell.** One literal command per call: absolute paths, `git -C <worktree>`, no shell variables,
  loops, `$(…)` or xargs — a guard hook may refuse the rest. Every `gh` call but `gh api` takes
  `-R <owner>/<repo>`.

## Steps

1. **Workspace.** Unless `--here`, fetch origin and cut a branch off latest `origin/main` (a
   sub-branch: `origin/<epic>`) in a new worktree, named the way the repo names branches (e.g.
   `<prefix>/<issue>-<slug>`). Enter it now, before any agent runs, and stay there. Driving several
   worktrees (epic sub-PRs), stay in the main checkout instead and give every agent absolute paths.
2. **Ground.** If this session hasn't grounded the task yet, do the reading in the `ground` skill.
   Put any decision that is the user's to them with AskUserQuestion, with a recommendation. Then
   hold no open assumptions.
3. **Plan.** Cut the work into packages and show it to the user before dispatching anything:
   - **Plain names.** Name each package for what it changes, e.g. `retry-on-timeout`. Never
     letters, numbers, passes or decision codes — not in the plan, the ledger, or updates to the
     user. Refer to decisions by a short phrase.
   - **Slice by outcome.** Each package leaves the build working and delivers one checkable outcome.
     Riskiest first, so a wrong assumption surfaces before the rest is built. Shared contracts
     (API specs, interfaces, schemas) and migrations go first and alone, then the packages that use
     them can run in parallel.
   - **Split when** a to-do item needs a paragraph, a package's outcome can't be checked in three
     bullets, its name needs an "and", or it spans two subsystems.
   - **One PR, about 300 changed lines.** Work bigger than that goes as an epic: an epic branch
     off main with a draft epic PR into main, the shared foundation committed straight to the
     epic, then independent sub-PRs of about 300 lines each, cut from the epic and merged into it
     in any order. Raise them all and merge each into the epic once its review, targeted tests,
     gate and codex are clean; the user merges the epic. Never a chain where one sub-PR branches
     off another. To sync, merge `origin/main` into the epic and push it in its own call — after `/gate`
     against `main` if the merge had conflicts (a clean merge adds no new code) — then merge
     the epic into each sub-branch, never `origin/main` directly.
   - **One wave at a time.** Detail only the packages about to run. Later ones stay a one-line list
     until the wave before them lands.

   Show it as one plain line per package (what it changes, and why), then wait for the user's go.
4. **Ledger.** Write `<notes-dir>/<issue-or-slug>-ledger.md`, outside any repo.
   Keep it under about 100 lines:
   - issue links, worktree path, branch and base sha
   - a link to the shared rules file, plus only the rules specific to this area
   - **Settled design**: the user's decisions in a line each, or a link to the design record
   - **Packages**: each with owned files, files not to touch, a to-do list, model, dependencies,
     and one existing file to copy the pattern from
   - **Status**: one line per package, rewritten in place with Edit as it moves. Never an appended log.

   An agent's prompt is the ledger path plus its package name, and it reads only its own package.
5. **Dispatch and check.** Launch independent packages together in one message. When one reports, a
   review agent walks its to-do list against the diff (Sonnet for mechanical work, Opus otherwise),
   marking each item done, partly done or not done with evidence. The implementer's own summary is
   not proof, and a report that is a plan rather than finished work is not done. Send any gaps back
   to the same implementer with SendMessage. Spot-check the work yourself, but don't redo it.
   Edit the package's line in the ledger's Status.
6. **Integrate.** Merge the PR's base through the `merge-main` agent — `origin/main` for a PR into
   main; for a sub-PR the brief names the epic as the base — then run the repo's tests once, scoped
   to what changed, through one `test-runner` agent if the repo has one. Send failures to the
   implementer that owns them, then re-run.
7. **Review.** Run the review skill inline in the main turn, never inside an agent. Judge each
   finding with the verdicts in `~/.claude/skills/codex-triage/SKILL.md` and fix only the **Fix**
   ones, through implementers. Re-run the tests if anything changed.
8. **Ship.** Merge the PR's base again if it moved, then run `/gate`, then push. Draft PRs and
   sub-PRs open and push without asking; ask the user before pushing to a PR whose CI is live (ready for review, or a run in
   progress), before marking a PR ready, and before opening a PR that starts CI. An agent drafts the PR body in the shape of
   `/ship-pr`'s Phase 1 template from the builders' reports and the review findings. Read and
   approve it; then the same agent opens the PR against its base (a sub-PR: `--base <epic>`, ready,
   not draft), sets body and labels the way the repo's CLAUDE.md says, and posts one PR comment listing
   each review finding with its outcome: fixed with the sha, or not fixed with the reason. Then run
   `/ship-pr`, in sub-PR mode for a sub-PR; it finds the open PR.

Stop and ask the user when a package hits a decision the ledger doesn't cover, when scope grows, or
when a fix would touch something marked off-limits.

Done when every package's to-do list has been checked by a reviewer, the tests are green, the
review findings are fixed or answered, and the PR is open with the findings posted.
