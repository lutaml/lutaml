# 03-scoreboard — Cross-implementation scoreboard

 interleaved A/B CPU-time medians per command (parse, compare, validate, flatten) against a pinned reference implementation, published per release and gating regressions (the moxml scoreboard pattern). Acceptance: the scoreboard rides the release workflow; a regression fails the gate.

## Status: done

- Harness: `Expressir::Scoreboard`
  (`lib/expressir/scoreboard.rb`, #545) — interleaved CPU-time
  medians over deterministic synthetic fixtures: parse on both shipped
  lanes (native core vs Ruby grammar), compare, population validate,
  flatten.
- Gate: `rake scoreboard:gate` — fails on a >2x regression against the
  committed baseline (medians swing ~2x on loaded boxes); the baseline
  path is `SCOREBOARD_BASELINE`-overridable, so CI and local
  toolchains gate against their own like-for-like measurement.
- Release riding: `.github/workflows/performance-release.yml` — on
  every completed `release` run (pinned `ubuntu-24.04`, load-settled,
  tree pinned to the released SHA) the scoreboard re-measures, gates
  against the committed CI baseline `scoreboard-ci-baseline.json`,
  and appends the table to the release notes (marked, idempotent
  section). `workflow_dispatch` with `seed_baseline` measures and
  publishes the JSON for committing.
- Specs: `spec/expressir/scoreboard_spec.rb` (harness rows, table
  rendering, gate logic).
