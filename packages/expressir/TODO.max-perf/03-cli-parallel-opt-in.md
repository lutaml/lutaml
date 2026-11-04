# TODO.max-perf/03 — CLI parallel opt-in and multi-file loader consolidation

## Context

The fork worker pool (PRs #349/#351) is strictly opt-in for library users.
The expressir CLI is application mode — our process — so it can opt in.
Today `commands/coverage.rb` calls `Parser.from_files` without
`max_processes` (sequential), and `commands/package.rb` calls
`Model::Repository.from_files` — a *second* multi-file loading path
duplicating the same orchestration (MECE violation).

## Work

- [x] `--max-processes` on `coverage` (default 4, Thor layer in cli.rb) and
      `package build` (default 1 — strict error semantics preserved)
- [x] `ParallelFiles.run` gained `strict:` — re-raises SchemaParseFailure,
      preserving Repository.from_files' fail-fast contract
- [x] `Model::Repository.from_files` now delegates its parse loop to
      ParallelFiles (shared orchestration, strict mode); tolerant
      Parser.from_files behavior unchanged
- [x] Specs: repository parallel == sequential (ids + order), strict raise,
      coverage/package suites green (57 + 57 examples)

## Acceptance

One multi-file loading pipeline; CLI bulk loads parse in parallel by
default; library default remains sequential.

## Status: done

- Multi-file loading is one pipeline with the pool path in `Expressir::Express::ParallelFiles` (lib/expressir/express/parallel_files.rb), gated by spec/expressir/express/parallel_files_spec.rb.
