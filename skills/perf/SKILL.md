---
name: perf
description: >-
  Measure a performance problem before touching it, find where the time goes, change one
  thing, re-measure, and report before and after numbers. Covers slow endpoints and queries,
  slow test suites and CI, and slow app screens backed by the backend. Also answers "does this
  change hurt performance" with numbers instead of opinion. Use for "it's slow", "why is
  this slow", "stays performant?", "does this cause perf issues", "measure and compare",
  "why does CI take 8m", or a perf issue number. Args: issue or PR number, endpoint, screen,
  test module, or a short description.
---

# perf

No optimisation without a number that shows the problem. Measure, find the cost, change one
thing, measure again the same way. A change that doesn't beat the noise is reverted.

All measuring and runs go to leaf agents — Sonnet for running a measurement, Opus for reading
a profile or plan, Haiku only for search. Tell each to spawn no sub-agents. One Maven build
machine-wide at a time (serialise Maven runs). Check the
project's memory notes first.

## Steps

1. **Pin the symptom.** What is slow, for whom, and how slow is too slow. If the ask is
   "does this change hurt", the question is the diff's hot paths — what runs more often or on
   more data than before.
2. **Check it's real.** Staging slowness can be the environment — a server upgrade, real S3
   against LocalStack, a cold cache. Read the issue history and earlier perf ledgers in
   `<notes-dir>` so a dead idea isn't tried twice.
3. **Baseline.** One command, fixed conditions, repeated enough to see the spread:
   - Endpoint or query: request timings against the running stack, and `EXPLAIN ANALYZE` on
     the query it runs. Count queries per request to catch N+1.
   - Test or CI time: count context boots, not wall clock — `Started X in N seconds` lines per
     module. Wall clock swings about 25% run to run. For CI,
     per-job timings from `gh run view <id> --json jobs`.
   - App screen: the network waterfall — which backend call, how many, how big.
4. **Find where the time goes.** Name the one cost that dominates: a scan where an index was
   expected, a sort above the scan, one query per row, an unbounded list, a payload loaded
   whole, a context forked by a `@MockitoBean`. A bad row estimate means stale stats, not a
   missing index.
5. **Sweep.** Same pattern elsewhere, and the convention the code follows. Index order and sort
   order are often deliberate — the slow site may be the outlier.
6. **Propose and stop.** Show the baseline, the cost found, and the one change proposed. A
   new index, cache or schema change is the user's call — every index taxes writes, every
   cache needs a key and a staleness window.
7. **Change one thing.** Smallest change that removes the measured cost. Nothing bundled.
8. **Re-measure.** Same command, same conditions as the baseline. Keep it only if it beats the
   spread and the tests stay green. Neutral or worse is a revert, and so is a win that needed a
   test changed.
9. **Report.** Before and after numbers in one line each, what changed in one line, and any
   idea tried and reverted with its number. Record reverted ideas in the ledger for that work.

Done when the user has before and after numbers from the same measurement and the change is
kept or reverted on them.
