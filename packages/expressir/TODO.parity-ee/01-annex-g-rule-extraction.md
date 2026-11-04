# 01 — Annex G rule extraction (executable spec for SHTOLO)

**Status: NOT STARTED**

## Goal

Turn `~/src/mn/iso-10303-11/sources/sections/ag-single-schema.adoc`
(1957 lines) into an executable checklist: every conversion rule with
an identifier, inputs, outputs, and a fixture that exercises it. This
is the contract both for our implementation (05) and for judging
eeng's coverage.

## Source structure (verified)

- Fundamentals: multi-schema → intermediate single "artifact" schema →
  rewrite using 1994-only constructs; subtype/supertype graph pruning;
  interface knowledge (visibility + instantiability) becomes rules;
  total_over constraints become rules.
- **Name munging**: name-clash policy; identifiers-as-strings.
- **Stage 1 (multi → intermediate)**: primary population (per
  interfaced item: artifact-schema rule + function capturing
  visibility/instantiability), secondary population, **prune** rules
  (rules whose parameters are not all visible are deleted, etc.).
- Stage 2 (intermediate → 1994 longform): rewrite of constructs not in
  the 1994 edition.

## Steps

1. Read the full annex; number every rule `G.<n>` with a one-line
   statement, inputs/outputs, and stage.
2. Build a fixture matrix: for each rule, the smallest STEPmod schema
   pair(s) that trigger it (mine the SMRL corpus for real cases).
3. Cross-reference which rules eeng implements (grep its sources for
   the mechanisms) and mark: implemented-in-eeng / our-gap / both-gap.
4. Encode the checklist as a spec document under
   `spec/fixtures/shtolo/rules.md` (or adoc) that 05's suite cites.

## Acceptance

Every rule in Annex G has an id, a fixture, and an eeng-coverage flag;
no rule left "uncategorized".
