# 07 — Schema compare & patch

TODO.parity-ee 16. Structural diff of two schemata with a
machine-applicable patch: declarations matched by canonical path
(`schema.item`); deltas added/removed/changed (per-attribute
structural diff: types, optionality, aggregates); patch output
declarable against the flattened base (eeng `--compare`/`--patch`
semantics, plugin/p11 compare entry).

## Status: done

- `Expressir::Express::SchemaCompare` — deltas at `schema.item` and
  entity-attribute `schema.item.attribute` paths; signatures are
  lutaml-model `to_hash` trees stripped of resolution artifacts
  (`base_path`, `ref`, `source`, remarks).
- `Expressir::Express::SchemaPatch.apply` — rebuilds the revised
  schema through the framework round trip; the base is never mutated;
  item-level `:changed` nodes subsume their attribute sub-deltas.
- Interfaces are out of scope by design: the patch target is a
  flattened (longform) schema.
- Oracle: `spec/expressir/express/schema_compare_oracle_spec.rb`
  agrees with `eengine --compare -MODE RESOURCE -STEPMOD <checkout>`
  on added/removed entities, removed attributes and enum-value type
  changes; gated on binary + stepmod checkout presence
  (EENGINE_BIN / STEPMOD_DIR).
