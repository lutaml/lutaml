# 20 — Coverage.find_nested_entities repeats 6-collection pattern three times

**Priority:** P2 (DRY violation)

## Problem

`lib/expressir/coverage.rb:404-477` — `find_nested_entities` has three
near-identical `when` branches for Function, Rule, and Procedure, each
concatenating the same six collections and recursing.

## Fix

Replace the three branches with a single loop over
`node.class.collection_attributes_list` (from the `collection_attributes`
macro) and recurse into children.

## Acceptance

- `find_nested_entities` has no model-class-specific case branches.
- All coverage specs pass.
