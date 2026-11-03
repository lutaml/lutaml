# 02 — check-p11 catalog completion

Folds TODO.parity-ee 07 + 12. Shipped subset: interface redundant,
interface resource duplicate, subtype ref/cycle, duplicate
declaration, where/unique name pattern, unresolved ref, select/enumeration
extended type, self-schema reference, parse failure.

## Sources

- `~/src/external/exp-engine-engine/kernel/check.lisp` (835 lines,
  per-node-type check-p11 methods) + `kernel/check-notes.lisp`.
- ISO 10303-11:2004 clause text:
  `~/src/mn/iso-10303-11/sources/sections/`.

## Port list (diff of eeng methods vs shipped subset)

Per eeng check-p11: entity attribute redeclare compatibility,
inverse target/entity/attribute existence, derive aggregation rules,
rule-entity reference containment, function/procedure parameter and
return checks, subtype-constraint reflexive/rule references,
constant expression constness. Each ported check keeps the eeng note
id and cites its ISO 10303-11 clause.

## Acceptance

- eeng-differential over the SRL corpus: every eeng-emitted note of
  the ported kinds is emitted here with matching schema/name; no
  false positives on clean corpora (express suite green).

## Status: done

Shipped across three tranches:

1. Original subset — interface redundant, interface resource
   duplicate, subtype ref/cycle, duplicate declaration, where/unique
   name pattern, unresolved ref, select/enumeration extended type,
   self-schema reference, parse failure; inverse target/entity/
   attribute checks; group references; aggregate bounds;
   check-attrib-name-fun.
2. Type-resolution tranche — constant/local/parameter/return types
   (eeng check-constant-type, check-local-type, check-parameter-type,
   check-fun-return-type) plus rule FOR entity refs.
3. Remainder — subtype-constraint supertype-expression refs (eeng
   kernel/check.lisp:426, check_supertype_ref note id) and
   SELF\ redeclaration resolution (ISO 10303-11:2004 9.2.2.3; eeng
   kernel/check.lisp:255 comment-only). Expression bodies are covered
   generically by check_unresolved_refs; eengine has no separate
   constant-expression constness rule (kernel/check.lisp only checks
   the constant's type), so that port-list item closes as covered.

Foreign-blindness rule: names that do not resolve in a single-file
parse (USE FROM targets of unloaded schemas) are skipped, not flagged —
both new checks verified note-free over 265 stepmod resource schemas.
