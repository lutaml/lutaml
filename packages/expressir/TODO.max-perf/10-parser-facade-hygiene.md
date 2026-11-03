# TODO.max-perf/10 — Parser facade API hygiene

## Context

The `Parser` facade accumulated internal helpers with public visibility
during the parallel work: `parse_files_sequentially` and `build_repository`
are implementation details of `from_files`. `Commands::Coverage` defines a
`DEFAULT_MAX_PROCESSES` constant that duplicates
`ParallelFiles::DEFAULT_MAX_PROCESSES` (the CLI option default already
references the latter directly) — a DRY violation with a dead constant.

## Work

- [x] `parse_files_sequentially` and `build_repository` are now
      `private_class_method` (no external callers existed)
- [x] Dead `Coverage::DEFAULT_MAX_PROCESSES` removed; the CLI option
      default references `ParallelFiles::DEFAULT_MAX_PROCESSES` directly
- [x] Rubocop clean; full suite green (1551 examples, 40s)

## Acceptance

Facade exposes only the public contract; single source for the worker-cap
constant.

## Status: done

- Facade narrowed and worker-cap single-sourced; suite green (in-file record).
