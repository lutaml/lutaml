# 25 — Debug puts statements in production code

**Priority:** P3 (cleanup)

## Problem

`lib/expressir/express/streaming_builder.rb:115,123,447-453` — `puts
"DEBUG ..."` guarded by `ENV["DEBUG_STREAMING"]`.

Using `puts` for debug logging means messages go to stdout mixed with
program output. No way to control log level programmatically.

## Fix

Use `Logger` or `Expressir::Benchmark.trace` for debug output. Or remove
the statements if they are stale.

## Acceptance

- `grep -rn "puts.*DEBUG" lib/` returns nothing.
- Streaming builder still works in debug mode (if retained).
