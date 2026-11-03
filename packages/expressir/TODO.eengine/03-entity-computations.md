# 03 — Entity computations

Matrix §3: eeng materializes inherited attributes and closures
(kernel/compute-inheritance.lisp, derive-attrs.lisp,
inverse-attrs.lisp, supertypes.lisp, explicit-attrs.lisp); expressir
walks supertype chains ad hoc. Needed by Annex G.2.6 select synthesis
(04/05) and the entity checks (02).

## Design

- `Entity#supertype_closure` — transitively closed supertype refs,
  cycle-safe.
- `Entity#inherited_explicit_attributes` — explicit attributes from
  the full closure, redeclaration-aware (SELF\\supertype.attr
  overrides).
- `Entity#derived_attributes` / `Entity#inverse_attributes` —
  accumulated from the closure.

## Acceptance

- chain + multiple inheritance + redeclaration fixtures; the
  materialization matches a hand-computed table.

## Status: done

- Inherited-attribute and closure materialization lives in
  `Expressir::Express::Shtolo` (interface closure, supertype
  inheritance), exercised by the Annex G audit specs.
