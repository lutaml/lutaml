# 00 — Compatibility & capability program overview

Expressir operates alongside established EXPRESS tooling in the same
ecosystem. This program has two goals: (1) compatibility faces for
existing toolchain invocations and interchange formats, so pipelines
can adopt expressir incrementally without rewrites; and (2) capability
expansion beyond what current implementations offer.

Interchange formats we already read (e.g. the `schema.changes`
comparison report) gain matching writers, so data flows both ways
across toolchains.

## Ladder

| n | task | tier | status |
|---|------|------|--------|
| 01 | comparison interchange: `expressir compare` emitting the `schema.changes` report, round-tripping with the existing importer | compat | done (#536) |
| 02 | compatibility guide + divergence register + `expressir doctor` workspace assessment | compat | done (#543) |
| 03 | cross-implementation scoreboard: interleaved CPU medians per command (`rake scoreboard`), baseline gate (`scoreboard:gate`) | compat | done (#545) |
| 04 | unified repository receipt: schemas + instance datasets + mapping tables in one deterministic, signing-ready artifact | capability | done (#548) |
| 05 | P28 configured binding (clauses 8/10) — the TODO.p28/05 promotion | capability | done (#549) |
| 06 | semantic change classification: breaking vs additive through the subtype graph (ISO 10303-11 Annex K policy) | capability | done (#550) |
| 07 | evaluator conformance matrix: ISO 10303-11 Annex B built-in coverage, mutation-tested | capability | done (#552) |
| 08 | WASM expressir-rs: schema + instance validation in browser/Node | capability | done (#551; expressir-rs#14) |

## Standing rules

- Compatibility faces mirror observable contracts (invocation shape,
  output format, exit codes) — never the internals of other tools.
- Every output format gets a round-trip or cross-read spec against the
  corresponding reader we already ship.
- Capability tasks cite the clause/annex they implement where
  applicable; no spec-invented behaviour.
- Divergences are registered (D-NN, the moxml register pattern), not
  silently blessed.
