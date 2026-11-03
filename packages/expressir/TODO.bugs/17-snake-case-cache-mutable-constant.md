# 17 — SNAKE_CASE_CACHE is a mutable module constant

**Priority:** P1 (unusual pattern)

## Problem

`lib/expressir/express/builder.rb:32`:

```ruby
SNAKE_CASE_CACHE = {} # rubocop:disable Style/MutableConstant
```

A module-level constant that is mutated in place at line 265 via `||=`.
It grows unboundedly across the process lifetime and violates the frozen-
constant convention the rest of the codebase follows.

## Fix

Either:
- Document it explicitly as an intentionally-mutable static-conversion
  cache and wrap it in a dedicated `SnakeCaseCache` class with a clear API.
- Replace with `Thread.current[:snake_case_cache] ||= {}` for thread-local
  bounded growth.

## Acceptance

- No `rubocop:disable Style/MutableConstant` needed.
- Cache behavior unchanged.
