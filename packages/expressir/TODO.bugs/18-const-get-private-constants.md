# 18 — const_get to access private constants from formatter modules

**Priority:** P2 (fragile access pattern)

## Problem

Formatter modules use `self.class.const_get(:INDENT)`,
`self.class.const_get(:OPERATOR_PRECEDENCE)`, etc. to access constants
declared `private_constant` on `Formatter`. ~10 call sites across:

- `formatters/declarations_formatter.rb:129,235,304,360,535`
- `formatters/expressions_formatter.rb:41`
- `formatters/data_types_formatter.rb:131,265,304`
- `formatters/supertype_expressions_formatter.rb:13`

String-keyed reflective access to bypass visibility makes the code harder
to grep and reason about.

## Fix

Remove `private_constant` on `INDENT`, `INDENT_CHAR`, `OPERATOR_PRECEDENCE`,
and `SUPERTYPE_OPERATOR_PRECEDENCE` since the formatter modules are
implementation details of Formatter anyway. Replace `const_get(:X)` with
direct `X` references.

## Acceptance

- `grep -rn "const_get" lib/expressir/express/` returns nothing.
- No `private_constant` on format constants.
- All formatter specs pass.
