# 15 — EXPRESSION_CHILDREN hash should be a model macro

**Priority:** P1 (parallel registry)

## Problem

`lib/expressir/express/remark_attacher.rb:30-45` has an
`EXPRESSION_CHILDREN` hash manually listing non-collection child attributes
for 14 expression/statement types. This is a parallel registry to the
`collection_attributes` macro and must be maintained separately.

## Fix

Add a `child_attributes` class-level macro on `ModelElement` (similar to
`collection_attributes`) for single-value child attributes that are
ModelElements but not collections. Register them the same way.

Update each expression/statement model class to declare its child attrs.

Replace `EXPRESSION_CHILDREN[...]` lookups in RemarkAttacher with
`ModelElement.child_attributes_registry`.

## Acceptance

- `EXPRESSION_CHILDREN` constant removed from RemarkAttacher.
- Each expression class declares its own child attributes.
- All remark specs pass.
