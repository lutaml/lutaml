# TODO.max-perf/04 — Repair the SRL benchmark harness

## Context

`benchmark/srl_benchmark.rb` has two defects found during the Sept 2026
validation:

1. The "Ruby Parser" pass calls `from_file(file, skip_references: true)`
   without `use_native: false`. Since native-became-default (2026-03-25),
   both passes run the native parser — the head-to-head comparison is
   mislabeled and meaningless.
2. Per-file `Timeout.timeout(30)` cannot interrupt the native FFI parse
   (GVL held), so pathological files hang the benchmark instead of timing
   out — observed as a 25-minute stall on an 8.6KB schema.

## Work

- [x] Ruby-parser pass (and warmup) now pass `use_native: false`
- [x] `parse_file_isolated`: per-file fork, length-prefixed Marshal results,
      TERM→KILL wall-clock escalation — pathological files terminate
- [x] `SRL_PATH` env override for reproducible smoke runs
- [x] Verified: 3-fixture run prints genuine Ruby-vs-Native numbers with
      truthful labels and terminates cleanly

## Acceptance

A short benchmark run prints genuine Ruby-vs-Native numbers, terminates on
pathological files, and labels passes truthfully.

## Status: done

- benchmark/srl_benchmark.rb is tracked, rubocop-clean and CI-linted; CPU-time methodology recorded after the mislabeled-pass fix.
