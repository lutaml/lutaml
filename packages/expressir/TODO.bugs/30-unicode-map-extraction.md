# 30 — build_unicode_to_asciimath_map is 80 lines of data inside a method

**Priority:** P2 (data-as-code)

## Problem

`lib/expressir/commands/validate_ascii.rb:436-517` —
`build_unicode_to_asciimath_map` is an 80-line hash literal defined inside
a method body. Should be a frozen constant.

## Fix

Extract to `lib/expressir/express/unicode_mapping.rb` as a frozen
constant.

## Acceptance

- The hash is a module-level frozen constant.
- All validate_ascii specs pass.
