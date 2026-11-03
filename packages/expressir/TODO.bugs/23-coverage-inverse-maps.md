# 23 — Coverage maps are manual inverses

**Priority:** P2 (DRY violation)

## Problem

`lib/expressir/coverage.rb:7-52` — `ENTITY_TYPE_MAP` and
`CLASS_TO_EXPRESS_TYPE_MAP` are 20-entry frozen hashes that are exact
inverses of each other. Adding or renaming a type requires updating both.

## Fix

Generate one map from the other at load time, or use a single canonical
list and derive both directions via `.to_h` and `.invert`.

## Acceptance

- Only one source-of-truth map exists.
- Both `ENTITY_TYPE_MAP` and `CLASS_TO_EXPRESS_TYPE_MAP` (or their
  successors) are derived from the single source.
- All coverage specs pass.
