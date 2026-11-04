# TODO.eengine — the eengine-parity program

Consolidates the remaining eengine-parity tasks (formerly scattered
across TODO.parity-ee) into one execution-ordered series. The oracle
is eengine-5.1.0 (GIT eeng-5.1.0) at `~/src/external/exp-engine-engine`; where
eengine and ISO 10303-11 disagree, the standard wins and the
divergence is classified in the differential output.

## Execution order and status

| n | task | folds | status |
|---|------|-------|--------|
| 01 | resolution diagnostics + USE/REFERENCE tiering | 06-remainder, 07-part | done |
| 02 | check-p11 catalog completion | 07, 12 | done (type-resolution tranche; generic unresolved-ref walk covers expression bodies; subtype-constraint supertype refs + SELF redeclaration resolution added; constness has no eeng rule — covered by the generic walk) |
| 03 | entity computations (inherited/derived/inverse closures) | matrix §3, 05-prereq | done |
| 04 | SHTOLO rule audit + corpus differential | 14-remainder | done (audit spec live; G.NM.2 + G.1.10 fixed; G.1.6 synthesis remains per annex-g-rules.md) |
| 05 | SHTOLO longform flatten (Annex G) | 05 | done |
| 06 | population / Part 21 reader + validation | 13 | done (parsanol reader; schema-mapping validator; Annex H corpus clean; eengine p21 differential blocked — eeng 5.1.0 aborts bare-p11 validate/*PARSE-MODE* NIL, every -MODE demands stepmod context) |
| 07 | schema compare & patch | 16 | done (SchemaCompare canonical-path deltas + SchemaPatch.apply; oracle differential vs eeng --compare green on add/remove entity/attribute + enum-value changes) |
| 08 | official corpus CI gate | 17 | done |
| 09 | MIM mapping parser | 18 | done |

## Sources

- eengine: `~/src/external/exp-engine-engine` (kernel/*.lisp,
  plugins/p11/*.lisp, plugins/p21/*).
- ISO 10303-11 clause text: `~/src/mn/iso-10303-11/sources/sections/`.
- Detached docs: `~/src/mn/iso-10303-detached-docs/sources/` (Part 21
  grammar, Part 28 text).

## Standing rules

- Semantics land in Ruby; parse-adjacent and graph-scale work lands in
  expressir-rs (TODO.parity-ee 19, option B).
- Where eengine and the standard disagree, the standard wins; every
  such divergence is classified in the differential output, never
  silently copied.
- Every ported check keeps its eengine note id for oracle
  cross-referencing, and cites its ISO 10303-11 clause.
