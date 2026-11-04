# 19 — All format methods must be public due to format_registry dispatch

**Priority:** P2 (encapsulation)

## Problem

`Formatter#format` dispatches via `public_send(handler, node)` at
`lib/expressir/express/formatter.rb:88`. This forces ~60 `format_*`
methods across 9 formatter modules to be public, even though they are only
ever called internally via the registry.

## Fix

Replace `public_send(handler, node)` with `send(handler, node)` in
`Formatter#format` (the handler comes from the trusted registry, not user
input), then mark all `format_*` methods as `private`.

## Acceptance

- `Formatter#format` uses `send` not `public_send`.
- Format methods are private in all 9 formatter modules.
- `Formatter.new.public_methods` does not include any `format_*` method.
