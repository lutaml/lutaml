# 21 — OPERATOR_TOKENS in Builder is a secondary dispatch mechanism

**Priority:** P2 (parallel dispatch)

## Problem

`lib/expressir/express/builder.rb:51-59` — 24-element `Set` of operator
token symbols, used at line 87 to decide whether to skip a nil-returning
handler. This set must be kept in sync with the grammar.

## Fix

Instead of maintaining a hand-curated set, check whether the handler
returns nil for ANY first-key handler when the hash has multiple keys, not
just for operator tokens. This eliminates the need for the set.

## Acceptance

- `OPERATOR_TOKENS` constant removed.
- Builder still handles multi-key hash AST correctly.
- All parser + builder specs pass.
