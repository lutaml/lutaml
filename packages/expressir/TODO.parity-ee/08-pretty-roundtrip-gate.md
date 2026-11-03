# 08 — Pretty-printer parity gate (eeng wo-pretty)

**Status: NOT STARTED**

## Goal

qualify.sh's core self-check, adopted for us: `.exp` → pretty `.exp`
→ re-parse → identical model; plus diff vs eeng's `-pretty.exp` over
the golden corpus so SHTOLO outputs (04/05) can target eeng-stable
formatting.

## Steps

1. Read `plugins/p11/wo-pretty.lisp` encoder (spacing, casing,
   remark policy, schema ordering) → document deltas vs our
   `Formatter` (clean mode).
2. Add `parser → formatter → parser` identity spec across the SMRL
   corpus (model-level to_hash equality, not bytes, first; byte mode
   only where eeng parity is wanted).
3. Byte-diff our pretty vs eeng pretty on the 03 corpus; decide
   adopt-eeng-format vs keep-ours (default: keep ours for rendering,
   eeng profile as an encoder option for SHTOLO artifacts).

## Acceptance

Corpus-wide round-trip identity green; eeng-profile diffs either zero
or explained line-by-line.
