# 13 — Add `:in_string` state to `RemarkScanner` (issue lutaml/expressir#313)

**Priority:** P1 (correctness limitation)

## Problem

`lib/expressir/express/remark_scanner.rb` runs a three-state machine
(`:top`, `:in_tail`, `:in_embedded`) but has no `:in_string` state. A `--`
inside an EXPRESS string literal is mistakenly treated as the start of a
tail remark.

Minimal reproduction:

```
SCHEMA string_tail_repro;
CONSTANT
  greeting : STRING := 'hello -- world';
END_CONSTANT;
END_SCHEMA;
```

Scanner returns 1 spurious `tail` remark: `"world';"`. Expected: zero remarks.

Reference: ISO 10303-11 §7.1.6.5 (Simple string literal) — `'` ... `'`
with `''` as the escape.

Filed as issue lutaml/expressir#313.

## Fix

Add a `:in_string` state to the state machine:

- At `:top`, when encountering `'`, enter `:in_string`.
- At `:in_string`, look for the closing `'`. Handle the `''` escape (treat
  as a single literal `'` inside the string, not a closer).
- At `:in_string`, ignore `--` and `(*` — they are string content.

Encoded string literals (`.X.` ... `.X.`) per §7.1.6.6 are rarer; defer to a
follow-up if not exercised by the SRL test schemas.

## Files affected

- `lib/expressir/express/remark_scanner.rb` (add `:in_string` state)
- `spec/expressir/express/remark_scanner_spec.rb` (add regression specs)

## Acceptance

- Scanner returns zero remarks for `'hello -- world'`.
- Scanner handles `''` escape correctly (`'it''s'` does not close at the
  middle `'`).
- All existing scanner specs still pass.
- The ISO §7.1.6.5 simple-string-literal case is covered.
