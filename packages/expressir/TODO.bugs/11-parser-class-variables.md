# 11 — Replace `@@cached_*` in `Parser` inner class with class instance variables

**Priority:** P3 (Ruby pitfall — `@@` vars shared across hierarchy)

## Problem

`lib/expressir/express/parser.rb:10-18`:

```ruby
@@cached_parser = nil
@@cached_syntax = nil
@@cached_exp_file_parser = nil
@@cached_grammar_ast = nil
@@parser_mutex = Mutex.new
```

Ruby `@@` class variables are shared across the entire class hierarchy, not
scoped to the defining class. If `Parser` is ever subclassed, the subclass
shares these caches — a footgun.

Currently not a bug (no subclassing), but fragile. Idiomatic Ruby uses
class instance variables (`@cached_parser` on the metaclass via `class << self`).

## Fix

Convert each `@@cached_*` to a class instance variable accessed via
`class << self` blocks or singleton method definitions. The mutex can stay
as `@@parser_mutex` since mutexes are typically process-global, but it's
cleaner to make it a class instance variable too.

## Files affected

- `lib/expressir/express/parser.rb` (or the split grammar.rb after TODO 09)

## Acceptance

- `grep -n "@@" lib/expressir/express/parser.rb` returns nothing.
- All parser specs pass.
- Cache behavior unchanged.
