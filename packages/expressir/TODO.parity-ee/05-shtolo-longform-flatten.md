# 05 — SHTOLO longform flatten (expressir#32) — the core port

**Status: NOT STARTED**

## Goal

Port eeng's flatten (Annex G) into expressir: convert the STEPmod
multi-schema web into ONE ISO 10303-11:1994 longform schema — no
interfaces, no name clashes, interface visibility/instantiability
preserved as rules, pruned unreachable declarations.

## Sources to port

- **Spec**: `ag-single-schema.adoc` (see 01's rule ids).
- **eeng**: `run-op (:flat)` + `print-flatten`
  (`plugins/p11/top-level.lisp:847`), writer `plugins/p11/wo-flat.lisp`
  (373 lines; note: eeng's flat output keeps structure and lowercases
  identifiers — verify how much of Annex G eeng actually implements
  before treating it as gospel; where eeng and the standard disagree,
  the standard wins and the difference goes into 02's matrix).
- **Model surgery**: `add-declaration.lisp`, `remove-declaration.lisp`,
  `copy-object.lisp`, `cleanup-interface.lisp`.

## Design sketch

1. Model-level `Expressir::Express::Flattener` operating on the
   resolved repository (compiled set warm model): build the artifact
   schema per Annex G — primary population (per interfaced item:
   visibility/instantiability rules + generated function), secondary
   population, name munging (clash policy), prune pass (rules whose
   parameters are not all visible; unreachable subtype branches),
   total_over → rules, then the 1994-construct rewrite.
2. Writer: reuse the formatter with a "flat/1994" encoder profile
   (no interfaces section; artifact rules emitted per Annex G).
3. Validation gates:
   - Annex G rule fixtures from 01 (each rule exercised).
   - Differential: flatten output vs eeng `.flat` over the 03 golden
     corpus; divergences classified standard-vs-eeng.
   - Output parses as 1994 (no edition-2-only constructs — the
     grammar-level edition profile check).
4. SMRL-scale run: all 132 SRL resources + module arm/mim set; memory
   via the compiled-set warm model.

## Acceptance

- All Annex G fixtures green; SMRL corpus flatten completes with zero
  unexplained diffs vs the 1994 profile.
- `expressir shtolo <manifest> -o longform.exp` ships.

## Tests

bug39's shtolo old-vs-new outputs (see 11) are an additional
differential: eeng shtolo vs stepcode exppp vs us.
