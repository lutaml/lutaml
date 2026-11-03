# 12 — Generate `COLLECTION_REGISTRY` entries from marker-module declarations

**Priority:** P3 (architectural; large change, defer unless time allows)

## Problem

`lib/expressir/model/concerns.rb` defines six marker modules
(`HasId`, `HasRemarkItems`, `HasRemarks`, `ScopeContainer`,
`HasInformalPropositions`, `HasWhereRules`) used for `is_a?` type checks.

`lib/expressir/express/node_position_index.rb` declares
`COLLECTION_REGISTRY` — a hash mapping the same model classes to their
collection attribute names.

Two parallel type-classification systems must be kept in sync. Adding a new
model type requires updating both. This is the same architectural smell that
TODO 06 addresses for a subset (Schema), generalized.

## Fix

Two options:

**Option A (declarative):** Each model class declares its own collection
attributes via a class-level macro, e.g.

```ruby
class Schema
  collection_attributes :constants, :types, :entities, ...
end
```

`COLLECTION_REGISTRY` becomes `Model.klasses.map { |k| [k, k.collection_attributes] }.to_h`.

**Option B (derived):** The marker modules carry the attribute list:

```ruby
module HasRemarkItems
  def self.collection_attributes = [:remark_items]
end
```

`COLLECTION_REGISTRY` is derived from `Model::Concerns.constants.flat_map { |c| ... }`.

Option A is cleaner. Either way, the duplication is eliminated.

## Out of scope for this PR

This is a large architectural change that touches every model class. It
warrants its own grill session to pick between Option A and Option B and
to migrate incrementally.

## Files affected

- `lib/expressir/model/declarations/*.rb` (add `collection_attributes` macro)
- `lib/expressir/express/node_position_index.rb` (derive `COLLECTION_REGISTRY`)
- `lib/expressir/express/remark_attacher.rb` (update reference)
- `lib/expressir/express/scope_resolver.rb` (update reference)
- All model class specs

## Acceptance

- `COLLECTION_REGISTRY` is derived, not hand-maintained.
- Adding a new model class with a `collection_attributes` macro automatically
  makes it appear in the registry.
