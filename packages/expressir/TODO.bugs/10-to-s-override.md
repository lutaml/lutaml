# 10 — Rename `ModelElement#to_s(no_remarks:, formatter:)` to `format`

**Priority:** P2 (surprising API; violates Liskov with core `to_s`)

## Problem

`lib/expressir/model/model_element.rb:191`:

```ruby
def to_s(no_remarks: false, formatter: nil)
  ...
end
```

Ruby's core `Object#to_s` takes zero arguments. Overriding it with keyword
args means `node.to_s` works (defaults kick in), but `node.to_s(no_remarks: true)`
is surprising — callers expect `to_s` to be a no-arg method.

The implementation also mutates the formatter after construction
(`f.no_remarks = no_remarks` at line 194), which is a post-construction
mutation of an option that should have been set at construction.

## Fix

1. Rename `to_s` to `format(no_remarks: false, formatter: nil)`.
2. Pass `no_remarks` through the formatter constructor instead of mutating
   after the fact.
3. Update all callers (search for `.to_s(no_remarks:`).
4. Optionally: keep a no-arg `to_s` that delegates to `format` for any code
   that expects string conversion (e.g. string interpolation).

## Files affected

- `lib/expressir/model/model_element.rb` (rename, update body)
- All callers — `grep -rn "\.to_s(no_remarks:"`

## Acceptance

- `grep -rn "def to_s" lib/expressir/model/` returns nothing (or returns a
  thin no-arg delegator).
- All specs pass.
- Callers use `.format(no_remarks: ...)` instead of `.to_s(no_remarks: ...)`.
