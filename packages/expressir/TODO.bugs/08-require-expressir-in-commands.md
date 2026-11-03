# 08 — Remove `require "expressir/changes"` from `commands/*.rb`

**Priority:** P2 (cleanup; project rule violation)

## Problem

Four call sites inside `lib/expressir/commands/`:

- `changes_import_eengine.rb:15, 27, 54`
- `changes_validate.rb:8`

All use `require "expressir/changes"` instead of relying on autoload.

The lazy requires inside method bodies suggest an attempt to defer loading,
but autoload already provides that — and the project rule says no `require`
with code within our library.

## Fix

Replace `require "expressir/changes"` with a direct reference to the
`Expressir::Changes` constant (which triggers autoload). If the require is
truly defensive (e.g., guarding against a load-order bug), delete it; the
autoload on `Expressir::Changes` in `lib/expressir.rb` covers it.

## Files affected

- `lib/expressir/commands/changes_import_eengine.rb` (delete 3 requires)
- `lib/expressir/commands/changes_validate.rb` (delete 1 require)

## Acceptance

- `grep -rn 'require "expressir/' lib/` returns nothing.
- All command specs pass.
- `Expressir::Commands::ChangesImportEengine` and `ChangesValidate` still work.
