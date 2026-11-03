# 15 — EXPRESS → XML (ISO 10303-28 / eeng --xml)

## Goal

Generate XML Schema output for a schema (expressir#276): eeng's
`--xml` (`wo-xml-p11.lisp`) plus the SMRL index listing
(`wo-smrl-xml.lisp`, feeds the SMRL document set).

## Sources

- ISO 10303-28:2007 ( EXPRESS-driven XML representation) — detached
  docs `~/src/mn/iso-10303-detached-docs/sources/iso-10303-28*/`;
  eeng `docs/` carries `express_model.dtd` + module.dtd (legacy
  forms).
- eeng: `plugins/p11/wo-xml-p11.lisp` (schema → XSD),
  `wo-smrl-xml.lisp` (SMRL index XML), `--xml` run-op.
- Consumer: iso-10303 repo's `schemas/data/*.xml` SMRL pages
  (rendered by metanorma today) — our output must be drop-in for
  that pipeline.

## Design

1. **SMRL index XML first** (small, high value for iso-10303): the
   index of all schemas in a repository (name, file, interfaces,
   counts) as the repo's data-layer source — replaces the
   hand-maintained entries.
2. **express2xsd**: schema → XSD via a declarative mapping table
   (entity → element+complexType, type → simpleType/complexType,
   select → choice, explicit attrs in order, supertype substitution
   groups for SUBTYPE OF, aggregates → minOccurs/maxOccurs). Emit
   through a Nokogiri-free XML writer (ROXML via lutaml-model where
   it fits; hand-rolled tree otherwise — the mapping is the product,
   not the serialization).
3. **CLI**: `expressir xml SCHEMA -o schema.xsd`;
   `expressir xml-index REPO -o smrl.xml`.

## Acceptance

- Output validates against the Part 28 reference XSDs (detached
  docs) for the fixture set; xsd diff vs eeng --xml on SRL corpus
  classified standard-vs-eeng.
- iso-10303 SMRL pages render from our generated index unchanged.

## Test cases

- eeng `scripts/build-xml.sh` full-corpus reference outputs;
  `test-tt{,1}.sh` (XML + Saxon HTM chain) as end-to-end smoke.

## Release checkpoint

SMRL index first (unblocks iso-10303 pipeline), express2xsd second.
