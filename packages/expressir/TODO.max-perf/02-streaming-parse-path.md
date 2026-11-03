# TODO.max-perf/02 — Fix or retire the streaming parse path

## Context

`Parser.from_exp(use_streaming: true)` — documented as the maximum-performance
path (construct-by-construct building via `Parsanol::Native.parse_with_builder`,
no full intermediate AST) — fails on every schema tested with
`Error::SchemaParseFailure` on parsanol 1.3.28 and 1.3.30. The feature is dead
weight until it works: callers cannot opt into it, and it skews the perf
picture (the fastest intended path is the broken one).

## Work

- [x] Reproduced on a 5-line schema: `parse_fresh(schema_grammar, block)` fails
      at end-of-input — parse_fresh has no packrat memoization, which EXPRESS
      requires (parsanol-ruby#52)
- [x] The true streaming path (`from_exp_streaming_builder`) is unreachable:
      its gate uses `defined?(Parsanol::Native.parse_with_builder)`, which is
      always nil for the extension's dynamically-dispatched methods; calling it
      directly yields empty models (builder protocol drift vs parsanol 1.3.30)
- [x] Removed both dead paths; `use_streaming: true` now raises
      `Error::StreamingUnsupportedError` with a precise message
- [x] Spec: spec/expressir/express/streaming_spec.rb
- [x] Upstream: covered by parsanol-ruby#59 roadmap (ractor-safe / stable
      parse_with_builder unlocks a rewrite of this path)

## Acceptance

Either `use_streaming: true` produces an equal model with a green spec, or
the breakage is precisely documented upstream and the path is explicitly
marked unsupported.

## Status: done

- Executed as the documented-blocked alternative: the streaming builder is blocked on parsanol's stable parse_with_builder (parsanol-ruby#59), recorded in TODO.max-perf/14; the path stays marked unsupported until then.
