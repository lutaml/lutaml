# TODO.max-perf/08 — Instrument and optimize Builder.build internals

## Context

TODO.max-perf/06 established the split (CPU-time, parsanol 1.3.30, 4 mid-size
SRL schemas): native parse 50%, `Builder.build_with_remarks` 48%, references
2%; within the builder, model build is 1.12s vs remark attachment 0.06s.
`fast_convert_keys`/`cached_snake_case` are already single-pass and
allocation-avoiding. The unmeasured stages inside `Builder.build`:

1. `builder.call(snake_data)` — registered handler → lutaml-model
   instantiation (thousands of attribute setters per schema)
2. `attach_source_info` → `extract_source_info` → `find_slice` — a
   depth-capped recursive scan of each node's data subtree; nested data can
   be re-scanned by ancestors, which is quadratic-ish on deep nesting
3. The `when Array` recursion

## Work

Findings: fast_convert_keys ran 172k–266k times per schema (~60 calls per
model node): build() descends into subtrees the parent's deep conversion
already scanned, so every subtree was re-scanned once per ancestor level.
attach_source_info is negligible (0.02–0.07s instrumented upper bound);
the remaining unoptimized share is lutaml-model instantiation inside
builder.call (upstream territory).

- [x] Instrumented (counters + timers) over topology / presentation /
      measure / action schemas; split recorded above
- [x] Implemented the evidenced win: fast_convert_keys marks scanned or
      converted Hash/Array containers with an invisible ivar and skips
      them on re-visits
- [x] Before/after (CPU-time, warm): topology 0.42→0.25s (−40%),
      presentation 0.27→0.22s (−19%), measure 0.43→0.30s (−30%),
      action 0.11→0.06s (−48%)
- [x] Full suite green (1551 examples) including golden-file parser specs;
      to_hash equality verified against pre-change output on all four
      schemas

- [x] Handler-level audit (TODO 14 overlap): `expression` 25.8% / `syntax` 15.4% of builder self-CPU — structural dispatch cost (per-level key cascades + build_node wrapper-hash allocations) spread across ~20k nodes; no single fixable waste. Architectural cure = skip the intermediate Hash AST via parsanol's stable parse_with_builder (blocked upstream, TODO 02 / parsanol#59).

## Acceptance

Numbers table for the three stages; either a measured improvement merged or
the cost definitively attributed to lutaml-model instantiation (which moves
the next step upstream to lutaml-model).

## Status: done

- Cost definitively attributed to lutaml-model instantiation (file records the attribution).
