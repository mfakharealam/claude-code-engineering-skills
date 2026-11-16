---
name: ship-pr
description: >-
  Push the current branch, open (or locate) its PR, and drive it to merge-ready
  with a Sonar-green-first loop: watch CI, auto-fix Sonar findings, then triage
  codex's review with the codex-triage skill and re-watch the build. Use when the
  user says things like "ship this", "push and create a PR and watch it", "run the
  PR loop", "watch the PR for sonar / build / codex", or "fix the sonar issues and
  the review comments".
---

# ship-pr — drive a branch to merge-ready

A loop that takes a verified branch from "tests pass locally" to "build green +
Sonar green + codex review addressed". **Sonar green is the first gate**:
clear it first, then answer codex, so the review fixes land on a clean build.

This skill runs **in the main thread** (it pushes commits and replies on the
user's PR — keep that visible), but it **delegates compile/test verification to
the `test-runner` agent** and **never busy-waits** — it uses a background poll
that re-invokes the main loop when a gate settles.

## Operating principle

At every gate, **report status, then act**. Don't ask for sign-off at each step
unless the user asked you to checkpoint — this is an autonomous loop. But do
surface: what's red, what you're fixing, and the fix before you push it. Only fix
findings that are *real*; reply to the rest with a reason.

**Ask first where CI is live.** Draft PRs and sub-PRs into an epic open and push
without asking. Ask the user before pushing to a PR that is ready for review or
has a CI run in progress, before marking a PR ready, and before opening a PR that
starts CI.

## Sub-PR mode

A sub-PR merges into an epic branch, not `main`. The phases below hold, except:

- **Base** is the epic: `gh pr create --base <epic>`, opened ready. Only the epic PR into
  main is a draft.
- **Sync** by merging `origin/<epic>`, once main has gone into the epic — never
  `origin/main` straight into the sub-branch.
- **No CI to watch.** CI and Sonar run on the epic PR once it is marked ready, so skip
  Phases 2–4 and Phase 5's re-watch.
- **Codex is yours to run**, right after the PR opens: `codex review --base origin/<epic>`
  in the PR's worktree, output to a file headed `## Codex review`, posted as a review —
  `gh pr review <PR> -R <owner>/<repo> --comment --body-file <file>`, since `codex-triage`
  reads reviews, not plain comments. Then run `codex-triage`. Don't wait for codex to post.
  Done when every finding is fixed or answered.

---

## Phase 0 — Confirm the branch is shippable

1. `git status` — note any uncommitted work. If there are uncommitted changes
   the user expects shipped, commit them (Conventional Commits; footer below) or
   ask. Don't push a dirty tree silently.
2. **Tests green?** If the user already verified, trust them. Otherwise delegate
   a focused run to the `test-runner` agent (never run `mvn test` / the suite
   from the main agent). Do not proceed past a red suite.
3. Confirm `gh auth status` works and you know the base branch — `main`, or the
   epic branch in [sub-PR mode](#sub-pr-mode).

## Phase 1 — Push + open/locate the PR

Merge `origin/<base>` — the PR's base — if it moved, then run `/gate`, then push.

```bash
BR=$(git rev-parse --abbrev-ref HEAD)
git push origin "$BR"
# Locate an existing PR for this branch, else create one.
gh pr list --head "$BR" --state all --json number,state,url
```

If none exists, create it against the base branch. Write the body for a reviewer who wasn't in
the session — concrete endpoints, tables and behaviour, no internal package names or decision
codes, no preamble. Before creating it, strike hedges on known facts, metadiscourse
("This PR…", "Below is…"), zombie nouns ("perform validation of" → "validate"), precautions that
don't change what the reviewer does, and officialese ("utilize", "in order to"). If the repo has
`.github/PULL_REQUEST_TEMPLATE.md`, fill its sections in
order and drop its `<!-- -->` hints; otherwise use this shape:

````markdown
## Summary
<one line: what changes and why.> Closes #NN

<the smallest picture that makes it clear, only if one line doesn't: a call-tree or file-tree
`diff` block, a pseudocode diff, or a Mermaid sequence>

## Evidence
**Before:** <the failing test, curl output or screenshot>
**After:** <the same, now passing>

## Merge danger
**Door:** one-way or two-way — <why>
**Blast radius:** <who or what breaks if it's wrong>
````

A one-way door can't be walked back by a revert: a Flyway migration, a data backfill, a wire
contract or a breaking OpenAPI change. End the body with the Claude Code footer. Capture the
**PR number** — everything below keys off it.

## Phase 2 — Discover the gating checks, then watch

Check names vary per repo, so **discover them** instead of hardcoding:

```bash
gh pr checks <PR>            # name <tab> state <tab> ... <tab> url
gh repo view --json nameWithOwner -q .nameWithOwner
```

Classify the checks:
- **Sonar gate** — the check whose name matches `/sonar/i` (may be absent; if so,
  skip the Sonar phase entirely).
- **Build gate** — the CI build/test check(s). Commonly named `build`, `ci`, or
  `test`. Treat everything that is *not* a review/orchestration check (`claude`,
  `coderabbit`, `review-needed`, `wait-for-checks`) and *not* Sonar as a build
  gate.
- **Review** — codex (Phase 5), handled separately.

Watch the build + Sonar gates with a **background poll** (the harness re-invokes
you when it exits — do NOT use `nohup`/`&`, that detaches it from tracking).
Write the watcher to a temp file and run it with `run_in_background: true`:

```bash
cat > /tmp/ship-pr-watch.sh <<'EOF'
#!/usr/bin/env bash
PR="$1"; BUILD="${2:-build}"   # build check name, discovered
for i in $(seq 1 90); do       # ~67 min at 45s
  out=$(gh pr checks "$PR" 2>/dev/null)
  build=$(echo "$out" | awk -F'\t' -v b="$BUILD" '$1==b{print $2}')
  sonar=$(echo "$out" | awk -F'\t' '$1 ~ /[Ss]onar/{print $2}')
  echo "[$(date +%H:%M:%S) #$i] build=${build:-absent} sonar=${sonar:-absent}"
  [ "$build" = "fail" ] && { echo "RESULT=BUILD_FAILED"; exit 0; }
  [ "$sonar" = "fail" ] && { echo "RESULT=SONAR_FAILED"; exit 0; }
  if [ "$build" = "pass" ] && { [ "$sonar" = "pass" ] || [ -z "$sonar" ]; }; then
    echo "RESULT=BOTH_PASS"; exit 0; fi
  sleep 45
done
echo "RESULT=TIMEOUT"
EOF
bash /tmp/ship-pr-watch.sh <PR> <buildCheckName>   # run_in_background: true
```

`gh pr checks` always reflects the **latest** head SHA, so the same watcher works
after every push — just relaunch it.

> Cadence note: a full reactor build can run 15–25 min; Sonar runs after build.
> The background poll costs nothing while you wait. If you must self-schedule a
> wake instead, prefer long intervals (1200s+) over short polling.

## Phase 3 — Sonar first (only if the Sonar gate failed)

Read findings with the **`sonar` CLI** (keychain-authenticated, so private
projects work). Check-run annotations can carry empty messages, and anonymous
SonarCloud API calls return `total: 0` on private projects. Take the project key
from `sonar-project.properties` or the root `pom.xml` `<sonar.projectKey>`:

```bash
sonar list issues -p "$KEY" --pull-request "$PR" --statuses OPEN,CONFIRMED --format table
sonar api get "/api/hotspots/search?projectKey=$KEY&pullRequest=$PR&status=TO_REVIEW"
```

If `sonar` is missing or `sonar auth status` fails, fall back to the check-run
annotations (`gh api repos/<repo>/check-runs/<id>/annotations`).

For each finding:
- **Fix it cleanly** — prefer the real fix over a suppression. Honor the user's
  recurring rules (e.g. S1172 unused param → remove or genuinely use, never a
  bare `@SuppressWarnings`; S5778 single-invocation lambdas; no system clock in
  tests). Watch for fixes that just *move* a finding (e.g. dropping an unused
  param from a method whose override would then be flagged — verify the override
  is `@Override`, which Sonar ignores).
- If a finding is a false positive for this codebase, don't contort the code —
  mark it with an evidence-citing comment:
  `sonar api post "/api/issues/do_transition" --data '{"issue":"<key>","transition":"falsepositive","comment":"<evidence>"}'`.

Then: **verify via the `test-runner` agent** (compile + the affected test
classes), commit (`fix: clear Sonar findings …` + footer), push, and **relaunch
the watcher**. Loop Phase 3 until the Sonar gate is green.

## Phase 4 — Confirm both gates green

Proceed only when **Sonar = pass AND build = pass**. If the build failed for a
non-Sonar reason, fetch the failing job's log
(`gh run view <runId> --log-failed`), fix, verify via test-runner, push, re-watch.

## Phase 5 — Codex review

Codex posts its review under the user's login,
as inline `**[P<n>]` comments plus a "Codex findings" summary.

1. If no "Codex findings" summary exists for the latest head yet, wait for it with
   a background poll of `~/.claude/skills/codex-triage/codex-items.sh <PR>` (cap
   ~20 min). If none arrives, report that and skip this phase.
2. Run the `codex-triage` skill on the PR. It validates each finding, fixes the
   real ones, replies on every thread, syncs the PR's base and pushes.
3. Relaunch the watcher and confirm the build goes green after its push.

When the build is green and every review comment is fixed-or-answered, report the
final state (PR URL, all gates green, review addressed) and stop.

---

## Mechanics & gotchas (learned the hard way)

- **Never `mvn test` from the main agent** — delegate to `test-runner`. Compile
  checks are fine, but routing test runs through the agent keeps context clean.
- **Background watcher must be harness-tracked** — run the poll script directly
  with `run_in_background: true`. Wrapping it in `nohup … &` detaches it; the
  harness then notifies you instantly (the launcher exited) while the real
  watcher runs orphaned and never pings you.
- **Sonar findings come from the `sonar` CLI**, not anonymous API calls or
  check-run annotations (private project → empty results / empty messages).
- **Multi-module builds**: if a fix touches a downstream module's dependency,
  build the affected modules in one reactor (`-am`) so you compile against
  reactor output, not a stale `~/.m2` jar. For api-only hand-written changes, a
  single-module compile against `.m2` is enough.
- **Commit footer**: the commit attribution your setup uses, and PR bodies end with:
  ```
  🤖 Generated with [Claude Code](https://claude.com/claude-code)
  ```
- **Don't push broken code.** Every push in this loop is preceded by a green
  test-runner verification of the changed surface.
- **Genericity**: discover PR number, repo, and check names per-repo at runtime.
  If a repo has no Sonar check, skip Phase 3; if codex never reviews, skip
  Phase 5. The loop degrades to "push → watch build green".
