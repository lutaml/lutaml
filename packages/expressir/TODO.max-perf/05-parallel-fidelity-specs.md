# TODO.max-perf/05 — Parallel-parsing fidelity specs

## Context

Parallel `from_files` equality is currently asserted on schema ids only.
The pool crosses a fork boundary via Marshal; deep structural equality is
the real contract. The progress-block regression merged in #349 (double
`schemas` extraction) proved the block/caller paths need dedicated specs.

## Work

- [x] Deep-equality spec: `to_hash` of parallel repository == sequential
- [x] Progress-block contract specs on both paths (schemas is an Array of
      Declarations::Schema)
- [x] Error-path specs: skip-vs-raise by mode (tolerant/strict), including
      the strict-mode re-raise of SchemaParseFailure
- [x] Gate specs: nil/1/<3 files and fork-less platforms never fork

## Acceptance

All fidelity specs green; `to_hash` of a parallel repository equals the
sequential one for a multi-fixture corpus.

## Status: done

- spec/expressir/express/parallel_files_spec.rb pins pool/sequential parity incl. the from_files nil-pad regression.
