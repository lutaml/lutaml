# 02 — Population-scale rule engine

TODO.sota/02 made rules runnable; this task makes them runnable over
whole populations, at corpus scale, with the cross-instance semantics
ISO 10303-11 requires.

## Parts (each ships)

1. Compiled rules: parse and resolve each WHERE / UNIQUE / global rule
   once per schema edition; apply the compiled form to many instances.
   The Ruby evaluator stays the semantics home — the native path is a
   measured-need escalation only (standing rule), with a benchmark to
   justify any move.
2. UNIQUE rules: per entity, each UNIQUE label's expression evaluated
   across the whole population with duplicate detection; labels
   combining attributes and aggregates handled; self-referential
   population patterns (instances referencing instances of the same
   entity) are just population lookups.
3. Global rules: `RULE ... FOR (e1, e2)` — the FOR set is all
   instances of the named entities; the rule body evaluates once per
   rule over that population (SIZEOF/QUERY/USEDIN over the whole
   population, not per instance); violation only on proven false
   (9.4); indeterminate is not a violation.
4. Derived and inverse consistency: derived slots must be `*` per the
   Part 21 mapping (validator has it); DERIVE expressions recomputed
   and cross-checked where a value is present; INVERSE attributes
   validated as population-consistent (every inverse view of the
   explicit relation is materializable).
5. Scale and determinism: an SRL-scale synthetic population (10^5
   instances) rule-checked within a documented runtime budget,
   published as a rake benchmark; identical population + schema
   edition → byte-identical report.

## Acceptance

- Spec examples per rule (firing + clean) citing 9.4 / 9.2.x.
- Annex H population: every WHERE rule provably passes at engine
  level; the seeded-fault population fails exactly the intended rule
  and no other.
- UNIQUE: a duplicated label pair is found regardless of file order;
  global rule: an aggregate violation (e.g. a FOR-set size rule) is
  caught once, with instance evidence.
- The benchmark artifact records the 10^5-instance run on this box.

## Status: done

- Part 1 (compiled rules): `Expressir::Eval::Population` — the
  engine resolves each rule once per schema edition: instances are
  bucketed per entity via the task-01 typing (`instances_for`,
  subtypes included), slot maps are cached per entity, and the Ruby
  evaluator stays the semantics home (no native path, per the
  standing rule).
- Part 2 (UNIQUE, 9.2.2.1): each UNIQUE label's attribute tuple is
  evaluated per instance and compared across the whole population —
  entity plus subtypes, file order irrelevant; an attribute outside
  the entity is an error finding, not a silent pass.
- Part 3 (global rules, 9.4): `RULE ... FOR (...)` evaluates once
  per rule with each FOR entity bound to the aggregate of all its
  instances (`SIZEOF`/`QUERY` over the population); a rule naming no
  resolvable entity is an error finding. Violation only on proven
  false; indeterminate is not a violation.
- Part 4 (derived/inverse): the Part 21 derived-slot discipline
  (`*`) is already enforced by the validator (p21_derived_slot);
  Part 21 files carry no derived values to recompute, and INVERSE
  attributes are population-derived (nothing to evaluate beyond the
  schema-side checker) — recorded as scope, not gaps.
- Part 5 (scale + determinism): `rake instance:benchmark`
  (POPULATION_SIZE overrides, default 100000) generates a synthetic
  schema+population, runs WHERE + UNIQUE + global checks, writes
  `instance-benchmark.json` (timings, findings, deterministic flag)
  and runs the check twice to prove byte-identical results.

## Validation

- `spec/expressir/eval/population_spec.rb` (9): WHERE applicability
  through subtypes, UNIQUE duplicates across subtypes regardless of
  order + unknown-attribute error, global rule firing/clean over the
  FOR aggregate, determinism, and Annex H clean at engine level;
  the eval chunk is 52 examples, 0 failures.
- 10^5-instance benchmark on this box: load + parse + check,
  `check_first` 29.36 s, `check_second` deterministic, findings 0
  (`/tmp/instance-bench-100k.json` from `rake instance:benchmark`).
