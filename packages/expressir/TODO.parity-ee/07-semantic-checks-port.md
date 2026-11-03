# 07 — Port eeng semantic checks (kernel/check.lisp)

**Status: NOT STARTED**

## Goal

A `check` operation in expressir that walks a schema/repository and
reports the same diagnostics eeng's check-p11 passes produce — the
validation half of the SHTOLO mission (inputs must be sound before
flattening).

## Source catalog (check.lisp, 835 lines)

Per-node `check-p11` methods: schema, use-from/reference-from,
constant, local, entity (explicit/derive/inverse attributes),
function/procedure/rule parameters, subtype_constraint, type, plus
expression/statement checks. Also `check-notes.lisp` (note
collection) and `compare.lisp` (schema comparison — two loaded
sessions).

## Design

- `Expressir::Express::Checker` modeled on our visitor infra; each
  eeng check becomes one rule with the eeng note id preserved for
  cross-referencing oracle output.
- Wire into `Repository#validate` (RepositoryValidator today is
  interface-level only).
- Run order: checks → report (eeng note ids + our explanation) →
  nonzero exit on error-class notes (eeng error severity model).

## Acceptance

Golden-diff check reports vs eeng for the 03 corpus subset; any
divergent verdict justified against Part 11 clause text
(`~/src/mn/iso-10303-11/sources/sections/`).
