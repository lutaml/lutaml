# 04 — Replace `public_send(handler, node)` in `Formatter#format` with conventional override

**Priority:** P1 (architectural friction)

## Problem

`lib/expressir/express/formatter.rb:85` dispatches formatting by looking up a
method name in a class-level registry and calling it via `public_send`:

```ruby
def format(node)
  return "" if node.nil?
  handler = self.class.format_registry[node.class]
  return public_send(handler, node) if handler
  warn "#{node.class.name} format not implemented"
  ""
end
```

Issues:
- `public_send` forces the format methods to be public on the including class,
  defeating encapsulation.
- A typo in a registered method name surfaces only at runtime, when that model
  type is formatted.
- IDE navigation and static analysis are defeated.
- The `format_registry` hash is a parallel dispatch table that must be kept in
  sync with the actual method definitions.

## Fix

Replace the registry dispatch with conventional Ruby method override. Each
formatter module defines `format_<node_class>(node)` methods, and the base
`Formatter#format` dispatches via a `case node` statement. Format methods
remain private.

This is a larger change touching 9 formatter modules. If full restructure is
too risky for a single PR, a smaller win is to add a registration-time guard
in `Formatter.included` that asserts the registered method exists via
`method_defined?` — at least typos fail at load time.

## Files affected

- `lib/expressir/express/formatter.rb` (rewrite `format` and the registration hook)
- `lib/expressir/express/formatters/*.rb` (8 modules — update registration calls)
- `lib/expressir/express/pretty_formatter.rb`
- `lib/expressir/express/schema_head_formatter.rb`
- `lib/expressir/express/hyperlink_formatter.rb`

## Acceptance

- `grep -n "public_send" lib/expressir/express/formatter.rb` returns nothing.
- All formatter specs pass.
- A typo in a registered method name fails at load time, not at runtime.
