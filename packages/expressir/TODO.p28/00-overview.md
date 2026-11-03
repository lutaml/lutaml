# 00 — P28 program overview

ISO 10303-28:2007 XML representations of EXPRESS schemas and data.
Sources: `/Users/mulgogi/src/mn/iso-10303-detached-docs/sources/iso-10303-28/`
(edition 1 of the full standard, revising the 2003 TS; clause map:
5 document, 6 derived schemas, 7 default binding, 8 configured
binding, 9 XML document creation, 10 configuration language;
annex C base XML schema, D document schema, E valid populations,
G configuration examples).

Starting point: `Expressir::Express::Xsd` (#276) renders the #276
v2-mapping XSD; the -28 default binding now lives in `Expressir::P28`.

## Ladder

| n | task | tier | status |
|---|------|------|--------|
| 01 | uos writer: population → clause 9 instance XML | data | done (#530) |
| 02 | uos reader: clause 9 instance XML → population; value-identical round trip | data | done (#531) |
| 03 | default XSD derivation to clause 7 with the exp: common namespace | schema | done (#532) |
| 04 | iso_10303_28 envelope: embedded express, header, uos (clauses 5 + 9.2.1) | document | done |
| 05 | configured binding (clauses 8 + 10) | configuration | deferred — the configuration-directive layer over the default binding; its own program; the default binding is the conformance core |

## Standing rules

- Semantics cite clause ids (e.g. `:check_p28_*`, `# sec_9.3.1.1`).
- Instances ride the P21 record model (`Population`/`Record`/
  `ComplexRecord`, TODO.instance/03) so P21 and P28 compose and
  round-trips are value-identical.
- Tool split: static structures (the envelope, its express/header
  children) are lutaml-model Serializables with XML mappings;
  schema-driven XML (uos content, derived XSD) is Moxml — its
  element names derive from the EXPRESS schema at runtime, which no
  static mapping can express. No hand-rolled serialization on model
  classes.
- The default binding (clause 7) is the target; configured behavior
  (clause 8/10 directives) is out of scope until 05.
