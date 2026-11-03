# 22 — Builder fast-path methods are trivial wrappers

**Priority:** P2 (dead code surface)

## Problem

`lib/expressir/express/builder.rb:232-259` — Six methods that each just
call `build_node(:symbol, data)`, adding no logic:

```ruby
def build_term(data) = build_node(:term, data)
def build_factor(data) = build_node(:factor, data)
def build_simple_factor(data) = build_node(:simple_factor, data)
def build_primary(data) = build_node(:primary, data)
def build_expression(data) = build_node(:expression, data)
def build_simple_expression(data) = build_node(:simple_expression, data)
```

Called ~25 times across the builders. The indirection provides no value
since `build_node` is equally readable.

## Fix

Inline the calls to `build_node(:term, ...)`, etc. Remove the six wrapper
methods. Reduce the Builder public surface.

## Acceptance

- `build_term`, `build_factor`, `build_simple_factor`, `build_primary`,
  `build_expression`, `build_simple_expression` removed from Builder.
- All call sites updated to `build_node(:term, ...)`.
- All parser + builder specs pass.
