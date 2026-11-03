# 26 — GenericEntity#children misplaced (P0 BUG)

**Priority:** P0 (correctness bug)
**Status:** FIXED

## Problem

`lib/expressir/model/data_types/generic_entity.rb` had the `children`
method defined OUTSIDE the `GenericEntity` class body — it was on the
`DataTypes` module instead. Calling `GenericEntity.new.children` would
raise NoMethodError.

## Fix

Moved `def children` inside the `GenericEntity` class body (before the
final `end`).

## Acceptance

- `GenericEntity.new.children` no longer raises.
- All tests pass.
