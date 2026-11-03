# 09 — Split `parser.rb` (1048 lines) into grammar + I/O service + schema-block scanner

**Priority:** P2 (architectural friction — file too large to navigate)

## Problem

`lib/expressir/express/parser.rb` is 1048 lines with three distinct
responsibilities crammed into one file:

- Lines 5-688: inner `Parser < Parsanol::Parser` class — 250 grammar
  `rule()` definitions plus keyword helpers.
- Lines 690-920: outer `Parser` class — `from_file`, `from_files`,
  `from_exp`, `from_exp_streaming_builder`, `from_exp_streaming`,
  `extract_schema_blocks` (file I/O orchestration).
- Lines 921-1046: `parse_schema_block`, `skip_spaces`, `skip_ws_and_comments`
  — a hand-rolled state machine for splitting multi-schema files.

The grammar rules, I/O orchestration, and schema-block scanning are three
distinct concerns. The current nested `Expressir::Express::Parser::Parser`
namespacing is also confusing — outer class wraps inner class with the same
name.

## Fix

Split into three files:

1. `lib/expressir/express/parser/grammar.rb` — the inner grammar class as
   `Expressir::Express::Grammar::Parser` (renamed).
2. `lib/expressir/express/parser/service.rb` — the outer class as
   `Expressir::Express::ParserService` with the I/O methods.
3. `lib/expressir/express/parser/schema_block_scanner.rb` — the
   `parse_schema_block` / `skip_spaces` / `skip_ws_and_comments` helpers as
   `Expressir::Express::SchemaBlockScanner`.

Keep `Expressir::Express::Parser` as a thin facade that delegates to
`ParserService`, for backward compatibility with all existing call sites.

This is a large mechanical change. Run the full test suite after each file
move to catch missing references.

## Files affected

- `lib/expressir/express/parser.rb` (becomes a thin facade)
- New: `lib/expressir/express/parser/grammar.rb`
- New: `lib/expressir/express/parser/service.rb`
- New: `lib/expressir/express/parser/schema_block_scanner.rb`
- `lib/expressir/express.rb` (update autoloads)

## Acceptance

- No file under `lib/expressir/express/` exceeds ~400 lines.
- All parser specs pass without modification.
- `Expressir::Express::Parser.from_file`, `from_exp`, etc. still work.
