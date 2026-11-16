# Claude Code engineering skills

Skills and subagents for Claude Code that carry a change from an issue to a merged PR.

## Who it's for

Engineers who work through GitHub issues and PRs with Claude Code and want a repeatable flow: pin down the problem, build with subagents, review, ship, and keep context across sessions. The skills report what they find and leave the decisions to you.

## What's in it

| Name | What it does |
|---|---|
| `ground` | Understand the problem behind a change before any work starts, then the approach. Read-only. |
| `grill` | A Q&A session that refines a problem and its solution until nothing is left assumed, then records the decisions. |
| `orchestrate` | Build a change end to end as the lead: subagents implement, you plan and review, then review, open the PR and post findings. |
| `deep-review` | Pre-merge review of the branch diff: the built-in `/code-review` plus one Opus agent per axis (conventions, fit, tests, spec match), merged into one verdict. |
| `gate` | Pre-push gate: runs the repo's own complexity or lint ratchet if it has one, then an Opus review of new code for KISS, YAGNI, DRY and surgical change. |
| `codex-triage` | Validate Codex review findings on a PR, fix only the real in-scope ones, reply on every thread, sync main and push. |
| `ship-pr` | Push, open or find the PR, and drive it to merge-ready: watch CI, fix Sonar findings, triage Codex, re-watch. |
| `cleanup` | After PRs merge, remove their worktrees and branches and bring the main checkout to latest main. |
| `debug` | Find why something is red, failing or stuck, fix the root cause and pin it with a test. |
| `perf` | Measure a performance problem, change one thing, re-measure, and report before and after numbers. |
| `research` | Answer "which is better" questions with the repo's current practice, credible sources and one recommendation. |
| `handover` | Write a handover note and a paste-ready prompt so a fresh session can resume cold. |
| `recap` | Say where the work stands from real state, not from memory of the conversation. |
| `retro` | Look back over a session and suggest changes to checks, steering files, memory, skills and tooling. Manual only. |
| `day-update` | Build the day's work update from git, GitHub and session transcripts across repos, and append it to `~/updates.txt`. |
| `minutes` | Turn meeting notes or a transcript into decisions, action items and open questions, checked against the real work. |
| `issue` | Raise a GitHub issue, or add a report comment to an issue or PR, with facts and evidence only. |
| `ui` | Design and build a UI change, mockup first: show it, wait for the OK, build in the repo's style, check in a browser. |
| `builder` (agent) | Implements one bounded slice of a written plan in a worktree, runs the repo's checks, commits, and reports. |
| `merge-main` (agent) | Commits pending work, merges the latest base into the feature branch, resolves conflicts base-first, never pushes. |
| `test-runner` (agent) | Runs the requested tests, returns exact counts and each failure's class, method and cause. Never fixes code. |

## Typical flow

`/ground` → `/grill` → `/orchestrate` → `/deep-review` → `/ship-pr` → `/codex-triage` → `/cleanup`

Run `/gate` before a push if the repo has a gate. `/handover` and `/recap` bridge sessions; `/debug` and `/perf` are used when something breaks or is slow.

## Install

```bash
git clone <this repo> && cd <this repo>
mkdir -p ~/.claude/skills ~/.claude/agents
ln -s "$PWD"/skills/* ~/.claude/skills/     # or cp -r
ln -s "$PWD"/agents/* ~/.claude/agents/     # or cp
```

Optionally adapt `CLAUDE.example.md` into `~/.claude/CLAUDE.md`. It holds the personal rules the skills are written to pair with: short answers, ask on decisions, minimal changes, subagent conventions.

## Configuration

Some skills use placeholders instead of fixed values. Set them by naming them in your `CLAUDE.md`:

- `<notes-dir>` — where ledgers, design records and handovers live, outside your repos.
- `<repos-dir>` — where your local checkouts live.
- `<org>` — your GitHub org or user, for cross-repo issue and PR searches.
- `<project-key>` — your Sonar project key.

Project-specific facts, such as the test command or gate, come from each repo's own `CLAUDE.md` and docs.

## Requirements

- Claude Code
- `gh` CLI, authenticated
- Optional: Codex CLI for `codex-triage`
- Optional: Sonar CLI for the Sonar steps in `ship-pr` and `debug`

## Design principles

- Ground claims in code. Trace whether a real caller reaches a concern before raising or fixing it.
- Subagents are leaves with small tasks and a to-do list. The lead keeps context for decisions.
- Run targeted tests, not full suites, and send module-wide runs to `test-runner` so output stays out of the lead's context.
- Check before outward actions: `issue` drafts before posting, `codex-triage` supports `--ask` and `--no-push`, `ship-pr` asks first where CI is live.
- Reply with plain, short output — the verdict first.

## License

MIT. See `LICENSE`.
