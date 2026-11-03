# 01 — Comparison interchange: `expressir compare`

`expressir compare BASE.exp REVISED.exp [-o report.xml]` runs
`Expressir::Express::SchemaCompare` across the two files' schemas and
emits the `schema.changes` interchange report (the format the existing
`changes` importer reads). Pipelines gain a two-way street: reports we
emit, our importer consumes.

## Mapping

- schemas are paired by downcased id across the two repositories; a
  schema present on only one side contributes all its declarations to
  additions / deletions respectively.
- deltas come from `SchemaCompare.collection_deltas` per collection
  (constants, types, entities, subtype_constraints, functions, rules,
  procedures), so removed declarations carry their kind even though
  the delta's node is nil.
- op :added → `schema.additions`, op :removed → `schema.deletions`,
  op :changed → `schema.modifications`; attribute-level deltas
  (paths deeper than `schema.item`) always land in modifications —
  an added attribute modifies its entity — with the qualified
  attribute path as the name.
- Emission goes through Moxml: lutaml-model's leptris-backed
  serializer mis-parses the interchange's dotted element names as
  namespace prefixes (upstream family of lutaml-model#997); the
  model layer stays lutaml-model (from_xml is unaffected).

## Acceptance

- Round trip: emit a report for a seeded old/new schema pair; the
  existing importer parses it and the additions/modifications carry
  exactly the seeded differences.
- Exit code 0 on success; a missing input file is a command error.
- Deterministic output: same inputs, same bytes.
