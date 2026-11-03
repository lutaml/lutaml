# 02 — Replace class-level `@exp_file`/`@repository` mutation in `Parser` with locals

**Priority:** P0 (state leak across sequential calls)

## Problem

`lib/expressir/express/parser.rb` outer `Parser` class stores parse results
as class-level instance variables:

- Line 723: `@exp_file = ::Expressir::Express::Builder.build_with_remarks(...)`
- Line 735: `@resolve_references_model_visitor = ResolveReferencesModelVisitor.new`
- Line 774: `@repository = Model::Repository.new(files: all_exp_files)`
- Line 778: `@resolve_references_model_visitor = ResolveReferencesModelVisitor.new`

These are `class << self` instance variables. Sequential or concurrent calls
to `Parser.from_file` / `Parser.from_files` overwrite each other's state.
The visitor is only used inside the method body — there is no reason to
retain it on the class.

## Fix

Return local variables from `from_file` and `from_files` instead of mutating
class state. Replace `@exp_file` with `exp_file`, `@repository` with
`repository`, `@resolve_references_model_visitor` with `visitor`. Delete any
`attr_reader` declarations that expose these.

## Files affected

- `lib/expressir/express/parser.rb` (rewrite `from_file` and `from_files`)

## Acceptance

- `grep -n "@exp_file\|@repository\|@resolve_references" lib/expressir/express/parser.rb`
  returns nothing.
- All parser specs pass.
- `Parser.from_file` returns the same value it did before.
