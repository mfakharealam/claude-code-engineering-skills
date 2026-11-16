---
name: issue
description: >-
  Raise a new GitHub issue, or add a report comment to an existing issue or PR, with facts
  and evidence only. Use for "raise an issue", "add an issue on <repo>", "add a comment for what's left on <n>", "note this on the issue". Args: the
  repo and topic, or an issue/PR number, plus optional --post to skip the draft check.
---

# issue

An issue states what is wrong and the proof. It does not say how to fix it, unless the user asks.

## Steps

1. **Pick the mode.** A new issue, or a comment on an existing issue or PR. Pick the repo from the
   prompt (a repo name, or one the user's CLAUDE.md lists). If the repo is
   unclear, ask.
2. **Gather the facts.** Read the code, logs, PR or run. Collect numbers, links, file paths and run
   ids. Keep only what you verified.
3. **Search for duplicates** (new issue only). `gh issue list -R <org>/<repo> --state all --search "<keywords>"`.
   Try two or three phrasings. If one covers it, say so and offer a comment on that one instead.
4. **Write it.**
   - Title: the problem in plain words.
   - Body: what happens, where, how often, the evidence. No fix, no suggested approach, no
     "we should". Add a fix only if the user asked for one.
   - Declarative wording. Never "per the meeting", "as discussed" or "from the call".
   - A comment on an existing issue is a report: what was found or what is left, one line each,
     with links.
   - Write for someone who wasn't in this session. The first line says the problem. Name the exact
     endpoint, table or run, not "the flow". Say "because" where one fact causes another. Cut any
     sentence the reader wouldn't miss.
   - Self-check before showing it. Strike hedges ("might", "potentially") on known facts,
     metadiscourse ("Below is…", "It's worth noting"), zombie nouns ("perform validation of" →
     "validate"), precautions that don't change what the reader does, and officialese ("utilize",
     "in order to", "prior to"). The no-fix rule above still holds.
5. **Show the draft and ask.** Print the title and body, plus labels and project fields. Wait for a go.
   Skip this only when the prompt already said to post or you were given `--post`.
6. **Post it.**
   - New: `gh issue create -R <org>/<repo> --title ... --body-file ...`. Assign to the user if asked.
   - Comment: `gh issue comment <n> -R <org>/<repo> --body-file ...`.
   - Set labels and project fields the way the repo's CLAUDE.md says.
7. **Reply** with the URL, one line.

Done when the issue or comment is live, it holds only verified facts, and the user has the link.
