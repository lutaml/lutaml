# 01 — uos writer: population → clause 9 instance XML

`Expressir::P28::Uos.emit` writes a unit of serialization (clause
9.2.2) for a `P21::Population` against an EXPRESS schema, using the
default binding (clause 7) encoding rules of clause 9:

- `<uos id="..." express="...">` with the ed-2 common namespace
  (`urn:iso:std:iso:10303:-28:ed-2:tech:XMLschema:common`) and the
  schema's target namespace prefix (clause 7 §"URI for the target
  namespace": preprocessor-chosen; default
  `urn:iso.org:standard:10303:part(NNN):version(V):defaultXML:Name`
  for registered standards, `URN:<owner>:iso_10303_28/<Name>` shape
  otherwise as in the clause 9 worked example).
- Every instance is a by-value entity instance element (9.3.1): the
  element name is the entity id with its first letter uppercased
  (§8.5.5 identifier conversion, worked example `car_model` →
  `Car_model`), carrying `id="id<n>"` derived from the P21 instance
  id.
- Explicit attributes (9.3.1.1) become child elements with the same
  capitalized name: strings/numbers/booleans (`true`/`false`,
  9.5.2)/logicals (`true`/`false`/`unknown`, 9.5.4)/enumeration
  items (9.6.1) as text; binaries as hexBinary (9.5.1); references
  as `<Ref_prefix="..."> ref="id<n>"/>` (9.3.3 by-reference);
  `$` (unset) omits the element for OPTIONAL attributes; aggregates
  of simple base types as whitespace-separated LIST text (9.8.1),
  aggregates of entity base as one child element per component
  (worked example `Control_points`).
- Complex (multi-instantiation) entities become `exp:complexEntity`
  (9.3.4) with one by-value child per supertype component.

## Acceptance

- The clause 9 car-ownership worked example (9.2.6.1) emitted from a
  population byte-compares (modulo formatting) against the annex
  XML.
- Annex E populations emit clean; every emission round-trips through
  the P21 value model value-identically.
- Mutation: corrupting one value changes exactly the intended
  element; a missing mandatory attribute is a writer error, not
  silence.

## Status: done

- `Expressir::P28::Uos.emit` (lib/expressir/p28/uos.rb) emits the
  clause 9.2.2 uos for a P21 population against its schema, with the
  encoding rules cited per clause in the module header (8.5.5 naming
  incl. the uppercase-Part-21-keyword fallback, 9.3.1.1 explicit
  attributes in Part 21 slot order, 9.3.3 refs, 9.5.1/2/3/4 value
  texts, 9.6.1 enumeration items, 9.8.1 LIST aggregates, entity
  aggregates as referenced components, 9.3.4 exp:complexEntity).
- Spec: spec/expressir/p28/uos_spec.rb — the clause 9.2.6.1 worked
  example reproduced, deterministic emission, the full value-encoding
  matrix (incl. Part 21 .T./.F./.UNKNOWN. re-encoding), `$`-slot
  omission, complex-entity roles.
