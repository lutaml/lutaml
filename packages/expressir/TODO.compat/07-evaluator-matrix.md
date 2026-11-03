# 07-evaluator-matrix — Evaluator conformance matrix

 ISO 10303-11 Annex B built-in function coverage of Expressir::Eval, mutation-tested per function. Acceptance: the matrix is generated, cited per clause, and mutation failures fail the suite.

## Status: done

- `Expressir::Eval::BuiltinMatrix`
  (`lib/expressir/eval/builtin_matrix.rb`): the clause 15 standard
  function inventory, every row cited per clause (15.1–15.29) with
  its coverage status. New this task: `BOUNDS`, `ROLESOF` and
  `VALUE_IN` join the dispatch; `FORMAT` and `VALUE_UA` are
  registered divergent (D-06), `ROLESOF` documented as degenerate.
- Generated matrix:
  `docs/_guides/compat/eval-builtin-matrix.adoc` — produced by
  `BuiltinMatrix.to_adoc`, deterministic (spec-asserted byte-equal
  across generations), every row present with its clause.
- Mutation-tested per function:
  `spec/expressir/eval/builtin_matrix_spec.rb` holds, for every
  implemented function, a clause example [arguments, expected,
  mutation]; the suite fails when a function drifts from its example
  OR when the example stops distinguishing the mutation (a surviving
  mutant fails the suite).
