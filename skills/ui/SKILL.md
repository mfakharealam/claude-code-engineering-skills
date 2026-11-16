---
name: ui
description: >-
  Design and build a UI change in the frontend repo, mockup first:
  work out what the screen is for, show a mockup and wait for the user's OK, build in the
  repo's own style, run its checks, walk it in a browser. Use for "add a mockup", "show me a
  small html mockup first", "looks cluttered / is there a better structure", "improve this
  screen", "run e2e walks", or a mockup file to adopt. Args: the repo, the screen, and an
  issue, branch or mockup path if there is one.
---

# ui

The user judges UI by looking at it. Show before building, build only what was agreed, and
prove it in a browser. Keep the logic plain — a screen renders what the backend answers and
never computes its way around a gap.

The repo's own CLAUDE.md names its dev command, check commands, browser tooling and sign-in
for the stack. Use those. The screen needs the backend running locally (start it per the repo's docs) and any
one-time provisioning or seed step the repo documents. Read the framework docs shipped in
`node_modules` before writing framework code.

## Steps

1. **Settle the checkout.** Branch off latest `origin/main` in its own worktree unless the user
   named one, before any agent starts.
2. **Understand the screen.** Read the repo's rules for the area, the current screen and the API
   calls behind it. Name the user, their main action, and the states the screen has: loading,
   empty, error, not-available-yet and no permission. For a given mockup, list what differs from
   today.
3. **Name the backend need.** In one line, say whether the UI needs a backend change, such as a
   missing field or endpoint. If it does, point to `/ground` for it. Never fake it in the UI.
4. **Show it first.** Screenshot the current screen. Write a static HTML mockup to
   `<notes-dir>/mockups/<topic>.html`, outside the repo. Use the repo's own
   colours, Lucide icons, words and realistic content, not a generic purple-card look. Give two or
   three variations when the user asks for options or the layout is open. Share the path with one
   line per variation, and stop until the user picks one.
5. **Build in the repo's style.** Reuse existing components and match the neighbouring screens.
   Keep the repo's hard rules from its CLAUDE.md (i18n tables, design tokens, shared components).

   Small components, composition over config props, the simplest state that works — no new
   state library, no clever caching. For bigger work, hand slices to leaf implementers (Opus for
   tangled screens, Sonnet for simple ones) told to spawn no sub-agents, commit and report.
6. **Run the checks** the repo's CLAUDE.md lists. If the user said to leave them to CI, push and watch CI
   instead.
7. **Walk it in a browser,** signed in against the real stack.
   - Add an e2e spec when the behaviour is worth pinning. Otherwise use a throwaway probe
     script that reuses the repo's sign-in helper and saves screenshots to `/tmp/ui-shots/`.
   - If Chromium is missing, run the repo's Playwright browser install command once.

   Cover every state from step 2, every supported language and direction, and a narrow width.
   Check the console is clean, and compare the screenshots with the "before" ones yourself.
8. **Report** what changed, the screenshot paths, the check results and any backend need. Ask
   before pushing or opening a PR unless the prompt asked for it.

Done when the user approved a mockup, the screen matches it, checks pass and a browser walk
shows it working.
