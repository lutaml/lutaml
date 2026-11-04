# 05 — Interop exports: EXPRESS as a source

Expressir as the interchange point between EXPRESS and the rest of the
modeling world. These mappings are contributions (no ISO mapping
exists) — every decision is documented in the output module's docs.

## Parts (each ships)

1. JSON Schema export: entities → object schemas (attribute order,
   OPTIONAL → nullable, aggregates → arrays with bounds where
   expressible, SELECT → anyOf, ENUM → enum). Subtype handling: the
   closure flattened into allOf groups. Documented decisions file.
2. OWL/RDF export: the ifcOWL lineage generalized to arbitrary
   EXPRESS — entities → classes, supertype closure → subclass axes,
   attributes → properties with domain/range from the model, SELECT
   → union semantics, WHERE rules NOT exported (documented scope
   limit). Cite ifcOWL/EXPRESS→OWL literature in the decisions file.
3. Optional tier: UML/XMI export.

## Acceptance

- Export the SRL corpus; a consumer round-trip (validate exported
  JSON Schema against a Part 21-derived JSON serialization of the
  Annex H population).

## Status: done

- Part 1 (JSON Schema): `Expressir::Interop::JsonSchema` renders a
  schema as JSON Schema 2020-12 — entities as object definitions
  composed with `allOf` over `SUBTYPE OF` parents, explicit attributes
  in declaration order, OPTIONAL attributes nullable and out of
  `required`, aggregates as arrays with declared bounds, SELECT as
  `anyOf` (BASED_ON folded), ENUMERATION as a string enum (BASED_ON
  folded), defined types through to their underlying primitive.
  Derived/inverse attributes, WHERE/UNIQUE rules and constants are
  documented exclusions. CLI: `expressir export-json-schema`.
  Decisions: `docs/_guides/interop/json-schema.adoc`.
- Part 2 (OWL/RDF): `Expressir::Interop::Owl` renders Turtle — entities
  as `owl:Class` with `rdfs:subClassOf` per supertype, explicit
  attributes as object/datatype properties with domain and range,
  SELECT as an `owl:unionOf` equivalent class, ENUMERATION items as
  individuals, primitive defined types as `rdfs:Datatype` with XSD
  equivalences; aggregates range over `rdf:List`. WHERE/UNIQUE bodies,
  cardinalities and aggregate bounds are documented scope limits. CLI:
  `expressir export-owl`. Decisions and the ifcOWL lineage citations:
  `docs/_guides/interop/owl-rdf.adoc`.
- Part 3 (UML/XMI): explicitly the optional tier; not shipped.
- Acceptance: the Annex H population is serialized to JSON in Part 21
  slot order (supertype attributes first, `$`/`*` null, references
  expanded with a cycle guard) and validated against the exported
  entity definitions with an independent consumer validator in
  `spec/expressir/interop/json_schema_spec.rb` — 13 instances, zero
  errors; dropping a required attribute fails. A gated
  `EXPRESSIR_CONFORMANCE` tier exports every schema in the stepmod
  resource slice (<250 KB; >200 schemas).
