# 03 — Thread `BuilderContext` through `Builder.build` instead of mutating `@source`/`@include_source`

**Priority:** P1 (architectural friction)

## Problem

`lib/expressir/express/builder.rb` is a `module` (not a class) that stores
per-call state as class-level instance variables:

```ruby
@source = source unless source.nil?
@include_source = include_source unless include_source.nil?
```

Lines 10, 49-50, 112-113. The `unless source.nil?` guard admits that this is
fragile — recursive `build` calls pass `nil` to avoid clobbering, which creates
an implicit ordering dependency between caller and callee. The module is not
reentrant: concurrent or nested builds would corrupt state.

## Fix

Introduce a `BuilderContext` value object that carries `source` and
`include_source`. Thread it through the recursive `build` call chain as a
keyword arg. Remove the `attr_reader :source, :include_source` on the
metaclass. Builders that need access read from the context.

Alternative considered: thread `source:` and `include_source:` as separate
keyword args through every `build_*` method. Rejected because the arg list
grows with every new context field, and the two values always travel together.

## Files affected

- `lib/expressir/express/builder.rb` (rewrite)
- `lib/expressir/express/builders/*.rb` (update call sites — most already
  receive `source` via `slice` or `node`; verify each)
- New file `lib/expressir/express/builder_context.rb`

## Acceptance

- `grep -n "@source\|@include_source" lib/expressir/express/builder.rb`
  returns nothing.
- All parser and builder specs pass.
- `Builder.build_with_remarks` is reentrant (a fresh `BuilderContext` per call).
