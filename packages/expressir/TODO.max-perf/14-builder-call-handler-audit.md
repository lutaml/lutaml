# TODO.max-perf/14 — Per-handler builder.call audit

## Context

TODO 08 attributed the remaining (post-memoization) builder cost to model
instantiation inside `builder.call` — but that was inferred, not measured
per handler. ~200 registered handlers exist (builders/*.rb); expressir-side
waste in the hottest handlers (e.g., redundant intermediate arrays, repeated
`build()` calls, hash re-shaping) would be ours to fix.

## Work

- [x] Instrumented per handler via a self-time build wrapper (child CPU
      subtracted) over representative schemas; top handlers recorded below
- [x] Inspected the top handlers' source (expression_builder.rb et al.)
- [x] No evident expressir-side waste to fix (see verdict below); the
      optimization taken instead was the fast_convert_keys memoization
      (merged in #355) after TODO 08's stage instrumentation
- [x] Full suite green

- [x] Handler-level instrumentation via a self-time build wrapper (child-time subtracted): 20,270 nodes, 1.58s self CPU over 3 schemas
- [x] Top handlers: expression 25.8% (3,184 calls), syntax 15.4%, entity_ref 7.7%, simple_expression 6.0%, entity_decl 5.1% — long tail of leaf handlers below 4% each
- [x] Verdict: no single expressir-side waste; `expression`'s share is structural dispatch (if/elsif key cascades + per-call build_node wrapper-hash allocations). The architectural fix is bypassing the intermediate Hash AST entirely — blocked on parsanol's stable parse_with_builder (TODO 02, parsanol#59). Recorded; not refactored blindly.

## Acceptance

Handler-level numbers table; either a merged improvement or the cost
definitively attributed to lutaml-model constructors (upstream follow-up).

## Outcome (from the 2026-09-18 close-out, commit 17aa264)

- [x] Instrumented per handler via a self-time build wrapper (child CPU
- [x] Inspected the top handlers' source (expression_builder.rb et al.)
- [x] No evident expressir-side waste to fix (see verdict below); the
- [x] Full suite green
- [x] Handler-level instrumentation via a self-time build wrapper (child-time subtracted): 20,270 nodes, 1.58s self CPU over 3 schemas
- [x] Top handlers: expression 25.8% (3,184 calls), syntax 15.4%, entity_ref 7.7%, simple_expression 6.0%, entity_decl 5.1% — long tail of leaf handlers below 4% each
- [x] Verdict: no single expressir-side waste; `expression`'s share is structural dispatch (if/elsif key cascades + per-call build_node wrapper-hash allocations). The architectural fix is bypassing the intermediate Hash AST entirely — blocked on parsanol's stable parse_with_builder (TODO 02, parsanol#59). Recorded; not refactored blindly.

## Status: done

- Handler audit table recorded (17aa264 record transplanted below); verdict: structural dispatch, fix is parsanol streaming.
