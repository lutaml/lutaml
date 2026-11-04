# 01 — Resolution diagnostics + USE/REFERENCE tiering

Folds the shipped remainder of TODO.parity-ee 06 (transitive USE and
the cycle guard are in; `interface_visibility_spec.rb` gates them)
with the tiering half of 07.

## Gaps

- USE FROM resolves **type + entity only**; REFERENCE FROM resolves
  constant/entity/function/procedure/type (eeng
  resolve-interface.lisp:30-66). Our resolution treats both alike.
- Unresolved resources: eeng hard-errors `Resource '~A' not found`;
  we warn (severity folded here from 07).

## Design

- `Schema#interfaced_items(kind:)` filters by interface kind.
- `Schema#resolve_item(name, kinds:)` walks own declarations then
  interfaces (transitively through USE for :use-from scope),
  cycle-guarded, honoring per-kind restriction.
- `Expressir::Express::Checker` reports unresolved references as
  errors (`E-RES-001`, the eeng note id family) with schema+name.

## Acceptance

- USE-only visibility: an interface's function is NOT visible through
  USE FROM; IS visible through REFERENCE FROM.
- Transitive USE chains still resolve (06's shipped behavior).
- Cycle-guarded resolution terminates.
- The checker flags an unresolved USE FROM resource as an error.

## Status: done

- Transitive USE, the cycle guard and the USE/REFERENCE visibility
  tiers are on main, gated by
  `spec/expressir/express/parser_interface_visibility_parity_spec.rb`.
