# 17 — Official test-case incorporation

## Goal

One place that maps every OFFICIAL/reference test corpus to our
specs, and CI gates that run the tractable tier on every push.

## Corpora

1. **eeng suite** (already imported, `spec/fixtures/eeng/`):
   `scripts/*.sh` 14 drivers (qual-arm/mod/res loops, pretty-test.sh
   ap209/210/242 × arm/mim × shortform/longform, ap210 giant file,
   test-tt{,1}.sh XML chain, build-xml.sh), `docs/issues/` bug
   corpus (bug39 shtolo old-vs-new vs stepcode exppp; bug40 pretty
   expressions), `qualify.txt`, `interfaces.txt`, `00check.txt`.
2. **ISO 10303-11** grammar/conformance sources:
   `~/src/mn/iso-10303-11/sources/sections/` — Annex G rules
   (fixtures live in `spec/fixtures/shtolo/annex-g-rules.md`),
   syntax annexes for negative/positive grammar tests.
3. **ISO detached docs** `~/src/mn/iso-10303-detached-docs/sources/
   iso-10303-*`: Part 21 exchange-structure fixtures (population),
   Part 28 reference XSDs (XML), Part 22 (SDAI vocabulary, later).
4. **SRL/SMRL corpora** (`resources.lst`/`modules.lst` names match
   our checkout): the differential tier.

## Structure

- `spec/expressir/eeng_parity/` — one spec per capability matrix
  row; each example tags its source corpus file in a comment.
- Tiering: `:fast` (fixtures, every push) / `:corpus`
  (SRL differential, nightly or manual tag `production_scale`) /
  `:smoke_eeng` (runs the local eeng oracle when the binary exists —
  skipped otherwise).
- `rake parity:status` prints the capability × corpus matrix with
  green/gray cells — the single progress view.

## Rules

- No test is added without its provenance row in the fixture dir's
  PROVENANCE.md (established practice, keep it).
- Oracle outputs are regenerated, never hand-edited; the regeneration
  command lives next to each golden.
