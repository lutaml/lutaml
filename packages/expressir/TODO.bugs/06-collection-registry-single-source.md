# 06 — Consolidate `SCHEMA_DECL_COLLECTIONS` into `COLLECTION_REGISTRY`

**Priority:** P1 (DRY violation — two sources of truth for the same fact)

## Problem

`lib/expressir/express/scope_resolver.rb:46` declares:

```ruby
SCHEMA_DECL_COLLECTIONS = %i[functions procedures rules entities types].freeze
```

This is a hard-coded subset of what `NodePositionIndex::COLLECTION_REGISTRY`
already knows for `Model::Declarations::Schema`:

```ruby
Model::Declarations::Schema => %i[
  constants types entities subtype_constraints
  functions rules procedures remark_items
]
```

`ScopeResolver` only needs the "named scope declarations" subset (it skips
`constants`, `subtype_constraints`, `remark_items` because they aren't scopes).
But the subset is implicit — a change to Schema's collection attrs in
`COLLECTION_REGISTRY` will not propagate.

## Fix

Define the subset once, either:
- (a) Filter `COLLECTION_REGISTRY[Model::Declarations::Schema]` against a
  constant of scope-capable attr names, OR
- (b) Lift `SCHEMA_DECL_COLLECTIONS` to a shared location and document it as
  "the scope-capable subset of Schema's collections."

Option (b) is simpler and more honest about the intent. Move
`SCHEMA_DECL_COLLECTIONS` to `Model::Declarations::Schema` as a class-level
constant, since the subset is a fact about Schema.

## Files affected

- `lib/expressir/express/scope_resolver.rb` (reference the model constant)
- `lib/expressir/model/declarations/schema.rb` (add `SCOPE_DECL_COLLECTIONS`)
- `spec/expressir/express/scope_resolver_spec.rb` (add a spec asserting the
  subset is a subset of `COLLECTION_REGISTRY`)

## Acceptance

- `ScopeResolver` no longer hard-codes a list that duplicates `COLLECTION_REGISTRY`.
- All scope_resolver specs pass.
- A new spec asserts the invariant: every entry in
  `Schema::SCOPE_DECL_COLLECTIONS` is also in
  `NodePositionIndex::COLLECTION_REGISTRY[Schema]`.
