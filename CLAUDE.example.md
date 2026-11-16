# How I work, across every repo

- **Answers.** Plain and short. Lead with the verdict or what's broken, and add the mechanism only
  when I ask. Use short sentences and em-dashes, not chains of semicolons. When I restate something
  in my own words and ask you to confirm, answer in my words. Start from what I already know and
  what I need to decide. Name the concrete thing — the table, the endpoint, the PR — not "the flow".
  Say the link between facts ("because", "so") instead of leaving it implied. When a sentence needs
  a fact only I have, ask for it rather than blur it.
- **Questions.** Look up facts yourself. Put decisions to me with the AskUserQuestion tool, with one
  or two lines of context and your recommended option first.
- **Simplicity.** Make the minimal correct change and reuse what exists. Before raising or fixing a
  concern, ground it in code by tracing whether a real caller can reach it. Skip guards for states
  that can't happen and machinery for far-off edge cases.
- **Git.** Cut new work off latest `origin/main`. Before a push, merge the PR's base — the epic for
  a sub-PR — then gate, then push.
- **Reviews.** Codex reviews PRs and posts under my login (inline `**[P<n>]` comments plus a "Codex
  findings" summary). Triage them with `/codex-triage`. The Claude review bot is not used, so never
  post `@claude review`.
- **Subagents.** Use Opus for complex work and Sonnet for simple work and verification. Use Haiku
  only for search. Every subagent is a leaf, so say "spawn no sub-agents" in its
  prompt. Give each one a small task with a to-do list. Implementers commit and report, and leave
  the test suites to the lead. Settle the worktree before the first agent call.
- **Notes.** Ledgers, design records and handovers live in `<notes-dir>`,
  outside the repos.
- **Skills.**
  - `/ground` builds the context behind a change.
  - `/grill` refines the problem and the design with me.
  - `/orchestrate` builds a change with subagents.
  - `/codex-triage` handles codex findings.
  - `/ship-pr` drives a PR to green.
  - `/handover` writes a note for the next session.
