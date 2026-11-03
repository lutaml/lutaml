# 04 — iso_10303_28 document envelope

The clause 9.2.1 document half: `Expressir::P28::Document` models and
emits the `iso_10303_28` envelope (annex D document schema) around
one or more units of serialization.

Tool split (per the engine mandate): ALL XML goes through moxml and
its leptris adapter — the envelope children are translated by module
functions like the uos faces, with the model layer as lutaml-model
Serializables (attribute typing and collections). lutaml-model's own
XML serializer is not used: 0.8.114's XML builder crashes on the
leptris adapter for every mapping (`Leptris::XML::Declaration`),
an upstream defect, filed as lutaml-model#997.

## Parts

1. `iso_10303_28` root element in the -28 common namespace (9.2.1):
   zero or more `express` elements (clause 5: `id`, `name`, embedded
   EXPRESS source — by value; referenced form via href later), zero
   or more `uos` elements (9.2.2, as emitted by `P28::Uos`), optional
   `header` (clause 5.2.1).
2. Emission: envelope over a repository (express by value) and its
   populations; the uos `schema` attribute references the `express`
   element's id (9.2.6.2).
3. Reader: parse the envelope back to express sources + populations
   (`P28::Uos.parse` per uos), value-identical round trip.
4. Validation: the envelope validates against a document schema
   assembled from `Xsd.base_schema` + the annex D components (as far
   as they are textual in the detachment; the images-only parts of
   annex C/D are re-derived from the normative clause text with
   citations, as in task 03).

## Acceptance

- The clause 9.2.6.1 car-ownership example emits as a full
  `iso_10303_28` document with the embedded express element and the
  uos referencing it, matching the standard's own example shape.
- Round trip value-identical: populations and express sources come
  back equal.
- Mutation: a uos referencing an unknown express id is a reader
  error, not a silent skip.

## Status: done

- `Expressir::P28::Document` (lib/expressir/p28/document.rb):
  `ExpressElement` and `Header` are lutaml-model Serializables
  (model layer); emission and reading are moxml/leptris module
  functions, as for `P28::Uos`. `Uos.emit` gained the 9.2.6.2
  `schema` attribute (`schema_ref:`) referencing the express
  element's id.
- The reader parses every embedded express source back into an
  EXPRESS schema and each uos into a population keyed by its schema
  reference; a uos referencing an unknown express id is a reader
  error.
- Spec: spec/expressir/p28/document_spec.rb — the clause 9.2.6.1
  envelope shape, value-identical round trip, header carriage, and
  the unknown-reference rejection.
- Upstream: lutaml-model 0.8.114's XML builder crashes on the
  leptris adapter for every mapping (`Leptris::XML::Declaration`);
  reported as the reason this file does not delegate XML to
  lutaml-model. The XSD validation gate keys on the leptris engine
  and skips on runners that fell back to a non-XSD walker.
