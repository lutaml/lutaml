# 03 — P21 ladder completion + population management + receipts

The file format, its management, and the citable validation artifact.

## Parts (each ships)

1. Ladder completion: annex E named data sections (multiple DATA
   sections, per-section schema binding), annex I ANCHOR/REFERENCE
   (anchors as cross-file identity; REFERENCE parameter binding),
   annex J constants and extended literals — the currently
   loud-failing fixtures become positives; genuinely malformed input
   still fails loudly with the intended finding.
2. Dataset manifests: a population manifest YAML binding dataset files
   to a schema-library release (file list, schema edition, short-name
   maps, section inventory); `expressir population validate MANIFEST`
   runs the whole stack (01 + 02) over every file and writes the
   receipt. Mirror of the schema-side ELF manifest.
3. Population diff/patch: instance-level compare (added/removed/
   changed instances keyed by identity and value digest — the
   population sibling of SchemaCompare), patch application, and
   subset extraction by entity closure.
4. Round trips: P21→model→P21 with a byte-stable mode; P21↔JSON
   promoted from the test bridge to public API (JSON Schema exporter
   exists; the population serializer is published with it); P28
   (ISO 10303-28 XML) read/write per the -28 mapping.
5. Validation receipts: deterministic JSON/YAML report — dataset
   digest, library release, validator version, per-rule verdicts with
   instance ids, summary counts — reproducible byte-for-byte. The
   citable artifact binding dataset to schema release (validator
   version included).

## Acceptance

- Annex E/I/J fixtures: positives parse and validate clean; malformed
  negatives fail with exactly the intended finding.
- Manifest-driven validation of a sample dataset produces two
  byte-identical receipts on consecutive runs.
- Population diff: a known edit yields exactly the expected deltas;
  P21↔JSON↔P21 is value-identical; P28 round trip validated against
  the -28 examples in the detachment.

## Status: done

- Part 1 (ladder completion): the P21 grammar and builder now carry
  the full ISO 10303-21:2016 ladder — named DATA sections with schema
  contexts (annex E; clause 11.2), the signature `..` header lines
  (clause 14), the ANCHOR section with promissory unset bindings
  (clause 9), the REFERENCE section binding local ids to external
  anchors (clause 10), and `#CONSTANT` references in parameters. The
  validator accepts REFERENCE-bound ids as known references and warns
  when a section's schema contexts miss the declared schema list
  (`:p21_section_context`). Annex E/I/J fixtures are positives;
  two extraction errata in the published detachment (annex E's
  unterminated string, annex J's missing paren plus an Asciidoc
  `....` delimiter — recorded in the detachment's own document.err)
  are corrected in the fixtures and cited in the spec header.
- Part 2 (dataset manifests): `Expressir::P21::DatasetManifest`
  (lutaml-model) binds files to a schema, a library release and
  short-name maps; `expressir population validate MANIFEST` runs the
  full stack (parse, typing, value conformance, rules) and writes the
  receipt; errors exit 1.
- Part 3 (population diff): `Expressir::P21::Diff.diff` —
  added/removed/changed by #id with keyword+parameter digests,
  complex records included; `expressir population diff A B` prints
  the deltas.
- Part 5 (receipts): `Expressir::P21::Receipt.build` emits the
  deterministic JSON receipt — release, schema, validator version,
  per-file SHA256 digests, per-note findings, summary. Same manifest
  + same files → byte-identical output (verified by consecutive CLI
  runs and by spec).
- Part 4 (round trips): `Expressir::P21::Writer.emit` re-emits a
  population deterministically (HEADER in insertion order, DATA
  instances in id order, anchors/references/named sections when
  present) with parse(emit(pop)) value-identical to pop;
  `Expressir::P21::Json` is the value-identical JSON interchange with
  explicitly tagged Part 21 value kinds (refs, enums, binaries,
  unset/derived, typed parameters).
- Part 4b (P28): deferred with reason. ISO 10303-28:2003+ encodes
  instances through per-schema DERIVED XML schemas (early binding,
  -28 clauses 8-9): a conforming reader/writer must first implement
  the -28 XML-schema derivation for arbitrary EXPRESS schemas, which
  is its own program sized like TODO.sota/03. The -28 source is
  present in the detachment (`sources/iso-10303-28/`) for that future
  work; nothing here pretends conformance.

## Validation

- `spec/expressir/p21/parser_conformance_spec.rb` (11): annex E
  sections/contexts, annex I anchors + SCHEMA_POPULATION +
  signature/reference variants, annex J constant references through a
  complex instance, malformed-input negatives.
- `spec/expressir/p21/{dataset_manifest,receipt,diff}_spec.rb` and
  `spec/expressir/commands/population_spec.rb` (10): manifest
  loading + short-name normalization, byte-identical receipts,
  finding records, diff deltas, CLI exit codes.
- p21 + commands chunks: 71 examples, 0 failures; eval + mapping
  chunks re-run green.
