# 01 — Delete stale `Transformer` autoload and legacy `transformer/remark_handling.rb`

**Priority:** P0 (load-time failure waiting to happen)

## Problem

`lib/expressir/express.rb:28` declares:

```ruby
autoload :Transformer, "#{__dir__}/express/transformer"
```

But `lib/expressir/express/transformer.rb` does not exist. Only the directory
`lib/expressir/express/transformer/` exists, containing `remark_handling.rb`
(195 lines). Any code path that references `Expressir::Express::Transformer`
raises `LoadError`.

The `transformer/remark_handling.rb` module duplicates remark scanning and
attachment logic that has been superseded by `RemarkScanner`, `RemarkAttacher`,
`ScopeResolver`, and `NodePositionIndex` (PR lutaml/expressir#314). It uses
`Parsanol::Slice`-based AST walking rather than source-text scanning, and its
`attach_untagged_remarks` is explicitly stubbed as "skip for now."

## Fix

1. Delete `lib/expressir/express/transformer/` directory entirely.
2. Delete the stale `autoload :Transformer` line in `lib/expressir/express.rb`.
3. Verify no callers reference `Expressir::Express::Transformer` anywhere.

## Files affected

- `lib/expressir/express.rb` (delete one line)
- `lib/expressir/express/transformer/remark_handling.rb` (delete file)
- `lib/expressir/express/transformer/` (delete directory)

## Acceptance

- `grep -rn "Expressir::Express::Transformer" lib/ spec/` returns nothing.
- Full test suite passes.
