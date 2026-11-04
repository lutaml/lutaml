# 01 — Instance typing + value/type conformance

Everything downstream (rule scoping, SELECT checking, ARM-view
queries) needs the answer to one question about every instance: which
entities does it conform to?

## Parts (each ships)

1. Typing engine: for every instance in a population, the set of
   entities it conforms to, through the subtype graph. Simple records
   (one keyword + supertype closure), complex records (multi-entity
   AND instantiation validated against the supertype constraints:
   ANDOR admissible, ONEOF exclusive, total-over respected),
   short-name resolution via the clause-12.3 map. Cached per
   population; public API `Expressir::P21::Typing#of(instance)`.
2. Slot value/type conformance: the clause-12 slot mapping (already
   in `P21::Validator`) extended with value-domain checking —
   primitive domains (INTEGER, REAL precision, NUMBER, STRING, BINARY
   width, BOOLEAN, LOGICAL), defined types unfolded to their base
   with the defined type's WHERE rules evaluated (ch.8 domain rules;
   the evaluator supplies evaluation), aggregates (LIST/ARRAY/SET/BAG
   bounds, SET uniqueness, element types, nested aggregates, ARRAY
   OPTIONAL elements), enumeration membership, and instance references
   checked against the target instance's typing from part 1.
3. SELECT membership: an attribute typed by a SELECT requires the
   referenced instance's typing to hit one of the SELECT's arms,
   through BASED_ON inheritance chains; findings name the arm tried.

## Acceptance

- One firing and one clean spec example per rule, citing the clause.
- Annex H population: every instance's typing computed; every slot
  value-conformant (zero findings).
- Mutation sweep: corrupting one value (wrong enum item, bound
  overflow, wrong reference type, bad complex combination) produces
  exactly the intended finding and no other.
- A complex-record population exercises ANDOR/ONEOF admissibility.

## Status: done

- Part 1 (typing engine): `Expressir::P21::Typing` — `of(record)`
  returns the entities an instance conforms to (keyword + supertype
  closure; complex records union their records' closures),
  `issues(record)` reports an unknown keyword, a repeated leaf in one
  complex instance (9.2.5) and ONEOF exclusivity violations
  (9.2.5.2 — the ONEOF groups of the supertype expressions and the
  ONEOF subtype constraints (9.7) reachable from each leaf).
  Short names resolve per ISO 10303-21 12.3.
- Part 2 (slot value/type conformance): `P21::Validator` now walks
  each clause-12 slot's declared type — primitives (8.1.1-8.1.7,
  with .T./.F./.U. as the Part 21 spelling of BOOLEAN/LOGICAL),
  defined types unfolded to their base with their WHERE domain rules
  evaluated through `Expressir::Eval` (9.2.2.2), aggregates (8.2.1
  ARRAY bounds + non-OPTIONAL unset elements, 8.2.2 LIST bounds,
  8.2.3 BAG, 8.2.4 SET uniqueness, nested element typing), instance
  references checked against the target instance's typing (9.2.1),
  and typed parameters unwrapped (`TYPED(v)` single-element
  unwrapping). Findings use `:check_p21_value_domain`,
  `:check_p21_aggregate`, `:check_p21_reference_type`,
  `:check_p21_select_arm`, `:check_p21_complex_instantiation`, each
  message citing its clause. `$` in a top-level slot stays tolerated
  (absent), matching the pre-existing contract; `:unset` inside a
  non-OPTIONAL ARRAY is a finding.
- Part 3 (SELECT membership): an attribute typed by a SELECT accepts
  a reference whose instance's typing hits an arm, a typed parameter
  naming an arm, or a literal accepted by a type arm — arms follow
  item entities, item defined types, nested selects and the BASED_ON
  chain (8.4.2).
- Parser note: `ANDOR` takes binary form (`a ANDOR b`), not a comma
  list; `FIXED` is reserved and cannot name an attribute.
- Also: `Expressir::Eval` is autoloaded from the gem root (the eval
  specs previously required it by hand).

## Validation

- `spec/expressir/p21/typing_spec.rb` (7) and
  `spec/expressir/p21/validator_types_spec.rb` (23: clean/firing per
  rule, the five-corruption mutation sweep where each corruption
  yields exactly one intended finding, and the Annex H population
  clean end to end through the full stack) — 61 P21 examples, 0
  failures; parser + mapping regression chunk 56/0.
