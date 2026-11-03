# Suma improvements — integration + expressir roadmap

The metanorma ↔ expressir chain via suma: ISO 10303 SMRL schemas → expressir
parse (compiled set EXSCS1) → LazyRepository + Liquid drops
(metanorma-plugin-lutaml) → metanorma-iso schema documents. The chain is
proven piecewise (1307 schemas, 0 failures, warm start 7.8s, live xrefs in
rendered XML); the items below close the last mile and deepen expressir.

| # | item | status |
|---|------|--------|
| 01 | prebuilt platform gems (oxidize-rb cross-gem, parsanol pattern) | in flight |
| 02 | suma full-document E2E on current stack | pending |
| 03 | ItemGraph — cross-schema subtype/interface graph API | pending |
| 04 | compiled-set + lazy path as suma default build | pending |
| 05 | corpus validation surfaced in suma builds | pending |
| 06 | memory/perf re-measure with binding-by-default | pending |
| 07 | #276 Part 28 XML — select mapping v2 | pending |
| 08 | windows gnu toolchain for in-place ext builds | superseded by 01 for CI; kept for local dev |
| 09 | checker tranche 3 (INVERSE, SELF\ qualifiers) | pending |
| 10 | #91 EXPRESSdoc (upstream-gated) | parked |

Evidence trail: #88/#461 (refpath validation), #462/#467 (ABSTRACT body
form), v2.4.21–v2.4.24 (binding by default), plugin 0.7.53 + #305/#306.
