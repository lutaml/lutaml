# TODO.max-perf/06 — Ruby-side (Builder) CPU audit on the current stack

## Context

After parsanol 1.3.30 (~2.5x further parse speedup), the native parse share
collapsed and the Ruby side — AstTransformer → Builder → lutaml-model
instantiation → remark attachment — is now the dominant parse cost
(sampled 2026-09-17: 72/28 Rust/Ruby on 1.3.28; native got ~2.5x faster
afterwards). March data ("removing Ruby transform: 2.5%") is obsolete.

Related landed work: f32f85f "eliminate allocation storms in remark
attachment" (another session, on main), 4c49e3a per-remark rescan guards.

## Work

Results (CPU-time, parsanol 1.3.30, 4 mid-size SRL schemas):

| phase | total | share |
|---|---:|---:|
| native parse (parse_native) | 1.595s | 50% |
| Builder.build_with_remarks | 1.530s | 48% |
| reference resolution | 0.080s | 2% |

Builder split: model build (`Builder.build`) 1.12s vs remark attachment
0.06s — remark attachment is already cheap (f32f85f); the cost is
AST-hash → lutaml-model instantiation.

- [x] Phase timing recorded (above)
- [x] Builder sub-phase split recorded (above)
- [x] Next target identified precisely: `Builder.build` per-node path —
      `cached_snake_case` / `fast_convert_keys` string allocations and
      lutaml-model constructor overhead (thousands of attribute setters).
      C stack sampling cannot name Ruby methods (vm_exec_core only);
      instrument inside Builder.build or add stackprof as a dev dependency
      before optimizing. Not refactored blindly — no safe evident win
      without that instrumentation.

## Acceptance

A numbers table attributing Ruby-side parse CPU to phases, plus either a
measured improvement or a precise, evidence-backed next target.

## Status: done

- Recorded through the stage and handler audits (TODO.max-perf/08 and /14).
