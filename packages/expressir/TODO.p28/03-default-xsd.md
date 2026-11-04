# 03 — default XSD derivation to clause 7

`Expressir::P28::Xsd` renders the ISO 10303-28:2007 default-binding
derived XML schema for an EXPRESS schema, so that clause 9 instance
documents (the task 01/02 uos faces) validate against it.

## Normative anchors (each cited in code)

- 7.7/7.7.3: one `xs:schema` with `targetNamespace`; `xmlns` for the
  target namespace, xs and the Base XML Schema; when present,
  `elementFormDefault`/`attributeFormDefault` shall be "unqualified"
  — the shape that makes qualified instance elements and unqualified
  accessor/component elements validate together.
- 7.7.4: `xs:import` of the Base XML Schema (exp:) — and of each
  interfaced schema's namespace once interfaces are in scope.
- 7.1.2: identifiers map with the initial letter upper case, all
  other letters lower case.
- 7.2: BINARY → `exp:hexBinary` (the base complexType with
  `extraBits`), LOGICAL → `exp:logical`, the rest per 7.2.1.
- 7.3: defined TYPEs → named `xs:simpleType` (restriction /
  enumeration facets keeping the EXPRESS item texts / `xs:list` for
  aggregates of simple base).
- 7.6.2: explicit attributes only — DERIVEd and INVERSE attributes
  are not mapped.
- 7.6.4: the entity `complexType` extends `exp:Entity`, holds the
  accessor declarations of the whole supertype closure (union,
  redeclarations winning) inside `xs:all`, `abstract="true"` per
  ABSTRACT SUPERTYPE.
- 7.6.5: one global instance element per entity in the
  `exp:Entity` substitution group.
- 7.8: the context-schema specific `uos` element over the entity
  instance elements (and `exp:complexEntity`).

## Base schema

`Expressir::P28::Xsd.base_schema` emits the annex C components the
default binding relies on, from the normative snippets in clause 7
(7.5.3.1 `exp:Entity`, 7.2.1.1 `exp:hexBinary`) plus the 9.5.4
logical domain and the 9.3.4 `exp:complexEntity` carrier.

## Acceptance

- The clause 7 shapes are present (unqualified forms, exp:Entity
  extension, xs:all closure union, substitution group, mapped names,
  enumerated facets, abstract flags, uos element, base import).
- DERIVEd/INVERSE attributes are absent from the derivation.
- End to end: a uos emitted by the task 01 writer validates against
  the derived schema; an unknown instance element fails validation.

## Status: done (#532)

- `Expressir::P28::Xsd.format` with the rules above; the normative
  form imports the base schema per 7.7.4, and `inline_base: true`
  inlines the same components under local names for toolchains that
  cannot resolve `xs:import` from an in-memory compilation (the
  libxml2-based moxml adapter being one).
- v1 boundary, stated in the module header: constrained
  widths/precisions emit no facet restrictions; SELECT accessors
  raise (the full 7.4 select machinery is future work); cross-schema
  supertypes raise rather than silently dropping attributes.
- Engine-strictness findings folded back in: inline-mode QName
  references are prefix-qualified (an unprefixed QName under a
  targetNamespace resolves to the empty namespace and stricter
  engines reject the schema at compile), the inline carrier is
  `uos_base` (no duplicate `uos` global), and the gate asserts
  `compile_error` is nil.
- Spec: spec/expressir/p28/xsd_spec.rb — shapes, 7.6.2.2 omission,
  and the end-to-end validation gate with a mutation.
