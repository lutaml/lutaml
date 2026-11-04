# 07 — Replace `require_relative` for `version` and `errors` in `lib/expressir.rb` with autoload

**Priority:** P2 (cleanup; project rule violation)

## Problem

`lib/expressir.rb:1-2`:

```ruby
require_relative "expressir/version"
require_relative "expressir/errors"
```

Project rule: never use `require_relative` for internal library code — use
Ruby `autoload` (defined in the immediate parent namespace's file).

`lib/expressir/express.rb:33` also has `require_relative "express/builder_registry"`
with a comment about eager-load for self-registration. The eager load is
justified for the builder self-registration pattern, but the rule still
applies — convert to autoload and require explicitly only in the entry point
that triggers registration (or restructure to lazy registration).

## Fix

1. Convert `version` and `errors` to autoload entries in `lib/expressir.rb`.
2. For `builder_registry`: convert to autoload, and explicitly trigger
   registration in `Builder.build_with_remarks` (the only entry point that
   needs builders loaded). Move the eager-load justification into a comment
   on that explicit require, or restructure builders to self-register lazily
   via `Kernel.singleton_class.include` at the top of each builder file.

## Files affected

- `lib/expressir.rb` (use autoload for Version, Errors)
- `lib/expressir/express.rb` (autoload BuilderRegistry; remove `require_relative`)

## Acceptance

- `grep -rn "require_relative" lib/` returns only justified entries (ideally zero).
- `Expressir::VERSION` still resolves.
- `Expressir::Errors::*` still resolves.
- Builder registration still happens before any `Builder.build_with_remarks` call.
