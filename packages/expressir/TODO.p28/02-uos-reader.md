# 02 — uos reader: clause 9 instance XML → population

`Expressir::P28::Uos.parse` reads a uos document back into a
`P21::Population`, inverting the writer's default-binding encodings
(TODO.p28/01), so the P21 and P28 faces share one value model and the
round trip is value-identical:

- by-value entity instance elements (9.3.1): the element name is
  matched against the schema's entity declarations via the inverse
  8.5.5 conversion; `id="id<n>"` maps back to `#<n>`;
- attribute accessor elements: text → string/number; `true`/`false`
  (9.5.2) and `true`/`false`/`unknown` (9.5.4) back to the Part 21
  logical renderings `.T.`/`.F.`/`.UNKNOWN.`; enumeration items as
  `.item.`; hexBinary binaries (9.5.1); `ref` attributes (9.3.3) to
  `#<n>` references; whitespace LIST text (9.8.1) back to arrays;
  entity-typed component elements to referenced arrays;
- `exp:complexEntity` (9.3.4) back to a `ComplexRecord` with one
  `Record` per role;
- unknown element names are reader errors, not silent skips.

## Acceptance

- Every emission in the task 01 spec corpus parses back
  value-identically: parse(emit(population)) == population at the
  record level (keyword + params, with booleans/logicals/enumerations
  compared under the Part 21 renderings).
- The clause 9.2.6.1 worked example XML (hand-written) parses to the
  same population the P21 source holds.
- Mutation sweep: flipping one attribute value or ref in the XML
  produces exactly the intended value difference in the parsed
  population.

## Status: done (#531)

- `Expressir::P28::Uos.parse` (lib/expressir/p28/uos.rb) reads a uos
  document back into a `P21::Population`: element names matched to
  schema entities via the inverse 8.5.5 conversion (unknown names are
  reader errors, not silent skips), accessor slots restored in
  Part 21 order with `$` gaps, logical faces (`true`/`false`/
  `unknown`) re-encoded to the Part 21 renderings through the
  DECLARED attribute types — including builtin primitives arriving
  as DataTypes or name references, defined-type chains, and
  9.8.1 LIST text — refs and ref'd components back to `#n`, and
  `exp:complexEntity` back to a ComplexRecord with one Record per
  role.
- Spec: spec/expressir/p28/uos_reader_spec.rb — the hand-written
  clause 9.2.6.1 worked example parses to the P21-equivalent
  population, the task-01 value matrix and complex/`$` corpus parse
  back value-identically, and the mutation sweep flips exactly one
  value or ref per finding.
