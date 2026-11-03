# 02 — The evaluator: run EXPRESS

The SOTA-defining capability: execute the language. Functions and
WHERE rules evaluated over Part 21 populations — the line between a
toolchain that reads EXPRESS and one that runs it. No open
implementation has this (eengine's --validate is the cautionary tale).

## Steps (each ships)

1. Value model + expression core: IMMUTABLE value classes (NUMBER
   family, STRING/BINARY, LOGICAL, enumeration, aggregate arrays as
   frozen structs), literal → value, pure expression evaluation
   (operators per 01's domain table), environmental lookup through a
   Scope chain. Interface: `Expressir::Eval.expression(ast, env)`.
2. Function interpreter: parameter binding (incl. VAR semantics),
   LOCALs with initializers, IF/CASE/REPEAT/compound/RETURN, ESCAPE/
   SKIP, recursion with depth guard. Builtin set A (math/string,
   ISO 10303-11 15.x): SIN..BLENGTH class.
3. Instance-aware builtins: TYPEOF, USEDIN, EXISTS, QUERY (lazy
   binding), attribute access through the model's computation layer
   (Entity#all_explicit_attributes, supertype_closure, redeclaration
   resolution — TODO.eengine/03), complex-instance (GROUP) access.
   Builtin set B (instance/aggregate: SIZEOF, HIBOUND..).
4. WHERE-rule checking: `Expressir::Rules.check(population, schema)`
   → per-instance, per-rule results with the failing subexpression
   path. Wraps the P21 Validator's structural tiers (TODO.eengine/06)
   into semantic validation.
5. Differential: eengine where its validate answers; property-based
   round-trips otherwise (evaluate a rule against a corpus population,
   cross-check pure-Ruby reference impls for builtins). If hot loops
   dominate, drop the evaluation core to expressir-rs (option B) —
   gate on measured need, not speculation.

## Design constraints

- The evaluator consumes the SAME model the parser produces — no
  parallel AST.
- Errors are notes/exceptions carrying node + path, never exit.
- Determinism: no reliance on hash order (corpus QA depends on it).

## Acceptance

- Annex-level worked examples (function bodies from ISO 10303-11)
  evaluate to the documented results.
- WHERE evaluation over the Annex H population: every rule provably
  passes; a seeded-fault population fails the intended rule only.


- Step 1 (value model + expression core): done — `Expressir::Eval`
  (Values/Environment/Expression autoloads): ISO 10303-11 ch.12
  arithmetic with result typing, logical tables (12.4), relational
  orderings (12.2.1), IN (12.2.3), LIKE (12.2.5, table 11 patterns),
  intervals, aggregates (tables 16-18 incl. element singletons), and
  QUERY. Indeterminate (`?`) propagates per clause. Function calls
  raise until step 2. Spec `spec/expressir/eval/expression_spec.rb`.
- Grammar bug fixed en route: `factor`'s `** rhs` capture was dropped
  by the builder (`2 ** 3 + 1` parsed as `2 + 1`); build_factor now
  emits EXPONENTIATION.
- Step 2 (function interpreter + builtin set A): done — functions
  with parameter/local binding, assignment (incl. indexed), IF/CASE,
  WHILE/UNTIL/increment REPEAT with SKIP and env-carrying ESCAPE,
  RETURN (falling off the end is an error per 13.7), recursion.
  Builtins: ABS SIN COS TAN ASIN ACOS ATAN ATAN2 SQRT EXP LOG LOG2
  LOG10 ODD LENGTH BLENGTH SIZEOF HIINDEX LOINDEX HIBOUND LOBOUND
  EXISTS NVL VALUE, plus PI/E/CONST_E constants. NOTE: the logical
  value symbols live in Values::LOGICAL_* constants — bare :true/
  :false literals get rewritten to booleans by Lint/BooleanSymbol.
- Step 3 (instance-aware evaluation): done — Values::Instance over
  P21 population records with P21-data-to-value conversion (arrays →
  aggregates, `#id` → instances, enums/binaries mapped); attribute
  access through the Environment's Part 21 slot mapping (inherited
  then own, same order as the P21 validator, incl. complex records);
  TYPEOF (unqualified + schema-qualified names), USEDIN, EXISTS.
  Fixtures: spec/fixtures/eval/population.{exp,p21}.
- Step 4 (WHERE-rule checking): done — `Expressir::Eval::Rules.check`
  evaluates every instance's entity domain rules with SELF and the
  mapped attributes bound (bare names and SELF\attr both resolve);
  statuses pass/fail/unknown/error; a rule is violated only when it
  evaluates false (9.4), indeterminate is not a violation.
- Step 5 (differential): done as substituted — eengine's --validate
  aborts on bare p11 (TODO.eengine/06 step 3 finding), so the
  differential face is the mutation sweep: corrupting one instance
  attribute fails exactly the intended rule and no other (rules spec).

## Status: done
