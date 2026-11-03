# 06 — Interface loading/resolution parity with eeng scheduling

**Status: SHIPPED (2026-09-21) — the resolution-side fix.**
`Schema#interfaced_items` is now repository-aware (foreign schemas
found through the parent chain into the enclosing repository) and
transitively USE-aware (items USEd by the foreign schema are visible,
unfiltered per the implicit-interfacing rule, cycle-guarded by a
visited-schema set). Probe results before/after: direct cross-file
item ref resolved; transitive-USE item resolved; interface cycle
terminates. Spec: `interface_visibility_spec.rb` (3 examples);
express suite 321/0. Remaining: unresolved-resource diagnostics and
USE-vs-REFERENCE error severity (eeng hard-errors; we warn) — folded
into 07's checker.

## Goal

Match eeng's multi-schema load semantics: which declarations are
visible where, transitive USE FROM (implicit interfacing), rename
(AS) handling, and error cases ("Resource '~A' not found").

## Differences already known

- eeng `resolve-interface.lisp`: USE FROM resolves **only**
  entity+type; REFERENCE FROM resolves constant/entity/function/
  procedure/type; unresolved resource = hard error. Our resolver
  stamps base_path but never errors on unresolved interfaces.
- eeng runs interface **scheduling** (schedule-interfaces.lisp) so a
  USE FROM can pull schemas already loaded in the session
  (schemata/schemata1/schemata2) — closest to our repository + graph.
- Implicit interfacing (11-interface_specification.adoc): items
  visible through USE FROM chains; our `interfaced_items` is
  single-hop — verify transitive semantics.

## Steps

1. From 02's matrix, list each semantic difference with a fixture
   (rename chains, transitively used items, interface cycles,
   missing resource).
2. Fix expressir resolution where we are wrong (spec wins), or
   document deliberate divergence.
3. Add unresolved-interface reporting (warning set) — SHTOLO's prune
   stage consumes it.

## Acceptance

Fixture suite covering rename/transitive/cycle/missing passes on both
paths (Ruby parser + core path byte-parity preserved).
