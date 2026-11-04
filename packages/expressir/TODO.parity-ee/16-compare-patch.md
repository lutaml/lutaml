# 16 — Schema compare & patch (eeng --compare / --patch)

## Goal

Structural diff of two schemata with a machine-applicable patch
output — eeng `--compare` (+ `--concat_compare`, `--patch`,
`--patch_schema_name`), used by WG12 to track schema revisions.

## Sources

- eeng `plugins/p11/wo-*.lisp` compare entry (`run-op (:compare)`
  in top-level.lisp) and patch application paths; mode args:
  `:trial_schema :reference_schema :xml-output :patch-output`.
- Semantics baseline: declaration-level matching by id within the
  flattened/concatenated form (eeng compares post-concat shapes for
  shortforms).

## Design

1. **Model diff** on the resolved repositories: declarations matched
   by canonical path (`schema.item`); kinds of delta — added,
   removed, changed (per-attribute structural diff: types,
   attribute lists, where/unique bodies via formatted-text
   comparison first, structural second).
2. **Outputs**: unified-ish text report (human), XML
   (`--xml-output` parity), and patch script (the eeng patch
   format: rename/redefine vocabulary it defines — ported from
   wo-patch output shapes).
3. **CLI**: `expressir compare TRIAL.exp REFERENCE.exp [--xml|--patch]`;
   `concat-compare` rides the Concatenator for shortform pairs.
4. **Patch application**: apply a patch file to a model (rename
   declarations, remap interfaces) — the write-back side eeng uses
   for round-trip patching.

## Acceptance

- SRL corpus self-compare = empty diff; mutated fixtures (rename,
  add/remove attr, retype) produce the expected delta kinds.
- Differential vs eeng `--compare` XML on the same pairs.

## Test cases

- eeng `docs/issues/` pairs; hand-mutated fixture ladder; the
  `--concat_compare` module-vs-module pairs from scripts.

## Release checkpoint

Text+XML diff first release; patch apply second.
