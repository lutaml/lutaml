# TODO.max-perf/09 — Grammar cold-start cost and disk cache

## Context

Every process boot builds the parsanol grammar and serializes ~2,300 atoms to
JSON (`Grammar::Parser.cached_parser` / `cached_grammar_json`) before the
first parse. Short-lived processes (CLI invocations, tests) pay this on every
run. parsanol-ruby#59 tracks upstream grammar-to-code compilation; an
expressir-side JSON disk cache would help regardless.

## Work

Measured (fresh process, 3 runs): boot (require expressir) 161–181ms,
grammar build ~28ms, JSON serialization ~30ms (83KB), first parse ~25ms.
Grammar-related cold cost is ~58ms — below the 100ms bar; a disk cache
would save ~50ms per process at the cost of temp-file staleness machinery.

- [x] Cold-start measured and recorded (above)
- [x] Documented as negligible — no cache implemented (the larger cold
      cost is the 161ms require boot, a separate lazy-loading concern)

## Acceptance

Cold-start number recorded; cache implemented with specs if the number
justifies it, otherwise documented as negligible.

## Status: done

- Cold-start number recorded in-file; cache documented as not justified.
