---
name: deep-review
description: Pre-merge "deep review" of the current branch's diff against the default branch. Runs Anthropic's built-in /code-review inline at the requested effort level for correctness and cleanup, alongside one parallel Opus-pinned agent per remaining axis — convention divergence, fit-to-problem (hacks/workarounds and unnecessary complexity), test coverage, and spec match (does it do what the issue asked) — judged against THIS repo's own CLAUDE.md / design/spec docs. Takes an optional effort argument (low/medium/high/xhigh/max) and defaults to xhigh when none is given. Verifies every candidate, then returns one merged findings list and a merge verdict. Use for "deep review / /deep-review / review this branch before merge / is this branch ready to merge?".
allowed-tools: Bash, Read, Grep, Glob, Agent, Skill, ReportFindings
---

# Deep review

Review the current branch's changes before merge. Operate on the diff of this branch against the repository default branch — nothing already on the base.

The review is a **single parallel wave: one owner per axis**. Each owner sees the same diff, owns exactly one axis, and stays out of the others' lanes. Correctness and security are owned by inline skill runs; the remaining axes each get one agent. The candidates are then verified, merged, and reported once.

**Every agent this skill launches runs on the latest Opus.** See the Model policy below — it is not optional and not effort-dependent.

**The wave is flat: one level of agents, never two.** No agent this skill launches may spawn sub-agents of its own. The built-in `code-review` and `security-review` skills have their own internal fan-out, so they are **run inline in the main turn** rather than wrapped in an agent — wrapping them buries a second layer of agents under the first, which multiplies cost, hides what is running, and makes the wave impossible to reason about. See Step 3.

## Review axes and their owners

| # | Axis | Owner |
|---|---|---|
| 1–2 | **Correctness** and **cleanliness/quality** — bugs, logic errors, reuse, simplification, efficiency | **Inline** — the main turn runs the built-in `code-review` skill at the **resolved effort**. No wrapper agent. |
| 3 | **No convention divergence** — conforms to the repo's own conventions and design docs; no new convention invented to prop up a hack | **Agent CONV** |
| 4 | **Fit to problem** — the two failure directions of one question, "is this the right amount of code?": band-aids, shortcuts, and special-cases papering over a root cause on one side; speculative flexibility, single-use abstractions, and complexity the problem doesn't warrant on the other | **Agent FIT** |
| 5 | **Well-tested** — new/changed paths covered (prefer unit tests) | **Agent COV** (static only). **No agent runs tests** — the suites run once at the end of the overall task (after any fixes), not inside the review wave |
| 6 | **Matches the ask** — does what the issue or design record asked: nothing missing or partial, nothing unasked, nothing implemented wrongly | **Agent SPEC** — only when Step 2 finds a spec |
| — | **Security**, when the diff warrants it | **Inline** — the main turn runs the built-in `security-review` skill. No wrapper agent. |

## Model policy

- **Every `Agent` call this skill makes — wave 1 and wave 2 — passes `model: "opus"` explicitly.** Never rely on inheritance from the session: the session may be running a different model, and an unpinned agent silently inherits it.
- **Never use `subagent_type: "fork"` anywhere in this skill** — forks ignore the model override and always run on the session model.
- **Every agent this skill launches is a leaf.** Tell each one, in its prompt, that it must not spawn sub-agents. The only fan-out below the top level is the internal pipeline of `code-review` / `security-review`, and those run inline in the main turn, so their agents are the session's own direct children — one level, not two.
- The inline `code-review` / `security-review` runs execute at the **session** model, because a `Skill` call cannot be pinned. That is the accepted trade for a flat wave. If the session is not on Opus, say so in the summary.

## When to invoke

- "deep review" / "/deep-review"
- "review this branch before merge" / "is this branch ready to merge?"
- Any pre-merge quality gate on the current feature branch.

## Workflow

### Step 0 — Resolve the review effort

The skill takes an optional effort level as its argument: `low`, `medium`, `high`, `xhigh`, or `max`.

- Use the level the user passed (`/deep-review high`, "deep review at max", and so on).
- **If no level is given, use `xhigh`.** Never fall back to `max` — `max` is opt-in only, because its fan-out is much wider.

State the resolved effort in the opening summary. It is then used in exactly three places: the inline `code-review` invocation, the wave-2 verification depth, and `level` on the final `ReportFindings` call.

### Step 1 — Resolve the diff scope

**Settle the working directory here, before anything else, and never change it again during the review.** If the branch under review lives in a separate git worktree, `EnterWorktree` into it **now** — in Step 1, while nothing is running.

Entering a worktree after the Step 3 wave has launched breaks every agent already in flight. The isolation guard is session-level, so it starts refusing Bash from any agent whose cwd was pinned to the shared checkout at launch, and those agents cannot rescue themselves: their own `EnterWorktree` is refused, and `cd` does not help, because the guard compares against the session's worktree rather than the command's path. They are left with `Read` on absolute paths and no `grep`, `find`, or `git` — so they either stall or start guessing file paths. Recovery is `ExitWorktree` with `action: "keep"`, then telling each blocked agent to retry.

Decide the directory once, up front: either review from the shared checkout for the whole run, or enter the worktree in Step 1 and stay there. **Never call `EnterWorktree` or `ExitWorktree` between Step 3 and the final report.**

Detect the default branch robustly, then scope to only this branch's commits (three-dot):

```bash
base="$(git symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null | sed 's#^refs/remotes/##')"
[[ -z "$base" ]] && for c in origin/main origin/master; do
  git rev-parse --verify --quiet "$c" >/dev/null 2>&1 && { base="$c"; break; }
done
[[ -z "$base" ]] && base="main"
git rev-parse --abbrev-ref HEAD          # current branch
git diff --stat "$base"...HEAD           # changed files + diff size
git diff --name-only "$base"...HEAD      # file list
```

Print the current branch, the resolved base, the changed-file list, and the diff size first. If the diff is empty (branch is at or behind base), say so and stop — there is nothing to review.

Note whether the diff touches auth/authz, tokens, minting/verification, ACL/scope, secrets, or crypto — that decides whether `security-review` also runs inline.

### Step 2 — Ground in THIS repo's conventions

Before fanning out, read the conventions the review must check against — **derive them from the repo you are in, do not apply generic ones**. Do this **inline with Read/Grep/Glob in the main turn** — never spawn an Explore or helper agent for grounding.

- The repo's root agent/convention file (`CLAUDE.md`, `AGENTS.md`, or equivalent).
- The module/package-level convention file for each module the diff touches (many monorepos have one per module; a module without its own defers to root).
- For any change to public contract or behavior, the repo's authoritative design/spec docs (e.g. `docs/`, an ADR tree). Where a repo declares such docs the **contract** (authority order docs > code), divergence of code from the docs is a code defect.
- **The spec for Agent SPEC** — the issues the branch closes (`Closes #n` in the commits or the PR body, read with `gh issue view <n> --comments`), plus any design record or ledger for them in `<notes-dir>`. If none exists, skip Agent SPEC and say so in the summary.

Examples of the *shape* to look for — substitute the current repo's actual rules:

- **Contract-first API** — the API spec is edited before generated code; generated sources are never hand-edited.
- **Migrations** — schema changes go through the migration tool; released migrations are immutable.
- **Config** — bound through typed config properties, not values read ad hoc.

Carry the invariants relevant to the touched files forward — they get pasted **verbatim** into the Step 3 agent prompts. An agent that has to re-derive the conventions wastes the pass.

### Step 3 — Fan out: one agent per axis, all in one message, then run `code-review` inline

Launch the conformance agents (three, or four with SPEC) **in a single message so they run concurrently**. Use `general-purpose` agents with `model: "opus"` on every call (see Model policy). Give each one: the base ref, the instruction to review `git diff <base>...HEAD` only, its single axis, and the Step 2 invariants verbatim.

Then, **in the main turn**, invoke `Skill(code-review, "<resolved-effort> <current-branch>")` and follow that skill's pipeline as written, including its own angle fan-out and its CONFIRMED / PLAUSIBLE / REFUTED verification. The three agents are already running in the background, so the wave stays parallel. Never pass `--fix`, `--comment`, or `--post` — this skill owns the final report, so hold `code-review`'s findings and merge them in Step 5 instead of reporting them separately.

**There is no Agent BUG.** Do not wrap `code-review` in an agent: its pipeline spawns its own sub-agents, and a wrapper turns those into grandchildren of this skill. Run it inline so they are the session's direct children.

- **Agent CONV** — convention and contract conformance against the repo's convention files and authoritative design docs. Where the repo declares docs the contract, code that diverges is the defect.
- **Agent FIT** — both directions of fit-to-problem in one lane. Hacks: band-aids, shortcuts, special-cases that paper over a root cause, a new convention invented to prop up a hack, dead-end error handling that hides a real failure. Overbuild: speculative flexibility, single-use abstractions, indirection that buys nothing, 200 lines that should be 50. Also the inverse — simplicity used as an excuse to cut a corner. Tag each candidate as `hack` or `simplicity`.
- **Agent COV** — are the new/changed code paths covered, preferring unit tests? Reads tests only; **does not run them**. A tautological test counts as uncovered — its expected value is computed the way the code computes it, so it can never fail.
- **Agent SPEC** — given the spec text, reports (a) asks missing or partial, (b) behaviour nobody asked for, and (c) asks that look implemented but wrongly, each quoting the spec line. Decisions settled later in the issue thread or the design record override the original body.
- **No Agent TEST.** Never spawn a subagent whose only job is to run the test suite. The suites run **once, at the end of the overall task** — after review findings are triaged and any fixes are applied — in the main loop, with output redirected to a file and only the summary/tail read back. (A subagent that is itself *making changes* may still run the single test classes it touches to verify its own work.)
- **No Agent SEC.** When Step 1 flags auth/authz, tokens, minting/verification, ACL/scope, secrets, or crypto, run `Skill(security-review)` **inline in the main turn** too, for the same reason as `code-review`. If the diff does not warrant it, say so in one line.

Instruct every agent to:

- Cite each finding as `file:line` with a concrete failure scenario.
- **Spawn no sub-agents.** Every agent here is a leaf — it does its own reading and searching and returns. State this in the prompt.
- **Stay in its lane.** Only the inline `code-review` run reports generic correctness bugs, style nits, and performance opinions; the agents report only their own axis. Overlap creates duplicates, not coverage.
- **Separate genuine defects from intentional design** — do not re-litigate deliberate decisions.
- Return read-only analysis as text; make no edits and call no reporting tool.

### Step 4 — Verify the conformance candidates, batched by axis

The inline `code-review` findings arrive already verified by that skill's own pipeline, but not against settled decisions — drop any that match a settled entry (below). The CONV / FIT / COV / SPEC candidates are not verified at all — hold them to the bar below.

Verification is **batched by axis, not per candidate** (except at `max`): one verifier agent per axis that produced candidates, each given the diff, the relevant file(s), **all** of that axis's candidates with the cited rule or claim for each, and the current project's memory dir if its `MEMORY.md` index has a "Settled, don't re-flag" section. Launch all verifiers **in a single message**, each with `model: "opus"`. Each verifier:

- Reads that settled section, and any known false positives the index lists, before judging. A candidate matching a settled entry is REFUTED, citing the entry.
- Writes its reasoning first, then a verdict per candidate — **CONFIRMED / PLAUSIBLE / REFUTED**.
- CONFIRMED names a concrete reproduction: a real production caller or input path, traced in code, that reaches the defect, or a test that would fail — for a convention or spec candidate, the rule or spec line quoted against the diff line that breaks it. PLAUSIBLE names one that hinges on a single fact it couldn't check, stated. If no real caller can reach it, or there is no reproduction, it is REFUTED however likely it sounds.

Keep CONFIRMED and PLAUSIBLE; drop REFUTED.

| Effort | Wave-2 verification |
|---|---|
| `low` / `medium` | **one** verifier agent for all candidates across all axes, batched into a single prompt; keep only CONFIRMED |
| `high` | up to **2** verifiers — fold the two smallest axes into one prompt |
| `xhigh` (default) | up to **4** verifiers — one per axis with candidates |
| `max` | one verifier **per candidate**, capped at **8** — highest-severity candidates first; say in the summary what was dropped |

### Step 5 — Merge and report once

1. **De-duplicate** the surviving `code-review` findings against the surviving conformance findings. On overlap, keep `code-review`'s wording and its `file:line`.
2. **Fold in coverage** — an uncovered new code path from Agent COV is a `test-coverage` finding. (Suite failures surface later, when the end-of-task test run happens — they are not part of this report.)
3. When `security-review` reports "clean" on an assumption, check the diff actually satisfies that assumption before accepting it.
4. **Report once** via `ReportFindings`, most-severe first, with `level` set to the resolved effort. Each finding carries `file`, `line`, `summary`, `failure_scenario`, its `verdict`, and a `category` naming the axis: `correctness`, `quality`, `hack`, `convention`, `simplicity`, `test-coverage`, `spec`, or `security` (Agent FIT findings use `hack` or `simplicity`, whichever the candidate was tagged). Do not also print the findings as prose.
5. If nothing survives, report an empty array and say so plainly — do not manufacture findings.

### Step 6 — Verdict

End with one clear line, noting that the full suites still run at the end of the overall task. Reference must-fix items by `file:line` only — do not restate finding text already sent to `ReportFindings`.

- **Ready to merge** — no must-fix findings; or
- **Not ready** — a numbered list of the blocking items by `file:line`, optionally followed by non-blocking nits.

## Agent budget

- **Wave 1 (Step 3): 3–4 agents** — CONV, FIT, COV, and SPEC when a spec exists. Correctness and security are inline skill runs, not agents.
- **Wave 2 (Step 4): at most 4** below `max` (axis-batched), **at most 8** at `max` (per-candidate).
- **Hard ceiling: below `max` this skill launches at most 8 agents of its own** (4 + 4). The only fan-out not counted here belongs to the inline `code-review` / `security-review` runs — governed by those skills' own budgets at the resolved effort. That internal depth is the knob the effort argument really turns; the axes themselves are the same at every level.
- **One level deep, always.** This skill's agents are leaves. Nothing it launches launches anything.
- **No unnamed agents.** Steps 0–2 (effort, diff scope, grounding) run inline with Bash/Read/Grep. Never add an Explore, scout, or helper agent beyond the ones named in Steps 3–4.

State the resolved effort, the wave-1 agent count, and whether `security-review` ran when you report, so the reader knows what actually executed.

## Constraints

- **Opus only.** Every `Agent` call carries `model: "opus"`; no forks. The inline `code-review` / `security-review` runs take the session model, since a `Skill` call cannot be pinned — say so in the summary if the session is not on Opus.
- **Flat wave.** No agent this skill launches may spawn sub-agents. `code-review` and `security-review` run inline in the main turn precisely so their internal fan-out stays one level down, not two.
- **Read-only.** This skill reviews; it does not edit, commit, or push, and never passes `--fix`, `--comment`, or `--post`. If the user wants fixes applied, that is a separate follow-up.
- **This branch only.** Always three-dot (`base...HEAD`) so base-branch code is never reviewed.
- **Repo conventions, not generic ones.** Every convention finding must trace to a rule in the repo's own convention files, design docs, or a listed invariant.
- **Everything gets verified.** No candidate reaches the final report without a CONFIRMED or PLAUSIBLE verdict.
- **One agent, one axis.** Lane discipline is what keeps the parallel wave from collapsing into five copies of the same list.
- **No test-running subagents.** Do not spawn an agent just to run tests. The suites run once at the end of the overall task, in the main loop, output redirected to a file with only the summary read back.
- **No re-litigating design.** Deliberate decisions are not findings; only defects, hacks, convention/doc violations, and coverage gaps are.
- **One report.** A single `ReportFindings` call at the end over the merged set — not one per agent.
