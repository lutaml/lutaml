# 13 — Population / Part 21 instance validation

## Goal

Validate STEP Part 21 instance data (.stp/.p21) against a loaded
schema — eeng's core strength (`--validate` with population), absent
from expressir today.

## Sources

- ISO 10303-21: exchange structure grammar — BNF in
  `~/src/mn/iso-10303-detached-docs/sources/iso-10303-21*/` (and
  eeng's copy under `plugins/p21/`, incl. its parser + validation).
- eeng: `plugins/p21/` (p21 reader, population), `--validate`
  (`run-op` population path), `wo-xml.lisp` instance-side references.
- eeng banner: population validation "not fully supported" upstream —
  our target is the supported subset, documented precisely.

## Design (scope ladder; each step ships)

1. **P21 reader**: parsanol grammar for the exchange structure
   (header entities + DATA section: complex entity `(`name(...)`)`,
   entity instances, list/set values, typed refs `#1`, enums `.T.`,
   binary `\"..."`, redefines `/`). Emit a Population model
   (`Model::Population`): instances with entity name + attribute
   values keyed by explicit attribute position.
2. **Structural validation**: every instance maps to a known entity
   in the schema closure (complex entities → all parts); attribute
   arity matches; value kinds match declared types (aggregate bounds,
   select members, string/binary widths, REAL precision) — the
   aggregate of eeng's population notes.
3. **Constraint validation**: UNIQUE rules (per-entity + inherited),
   WHERE rules — evaluation needs an EXPRESS expression interpreter;
   reuse/extend the `benchmark`/expression-walk machinery, evaluate
   over instance bindings (scope: no INVERSE/derives first).
4. **CLI**: `expressir validate population SCHEMA -p DATA.p21`,
   JSON/plain reports aligned with Checker notes.

## Acceptance

- Official Part 21 test corpora parse + validate (see tests).
- Differential vs eeng `--validate` on shared fixtures: same
  accept/reject decision and note ids.

## Test cases

- ISO 10303-21 validation suite files from detached-docs where
  available; else eeng `tests/` + `scripts/test-tt*.sh` fixtures.
- Hand fixtures: arity mismatch, bad enum, UNIQUE collision, WHERE
  failure, complex-entity mismatch.

## Release checkpoint

Steps 1–2 = first release (structural validator); step 3 second.
