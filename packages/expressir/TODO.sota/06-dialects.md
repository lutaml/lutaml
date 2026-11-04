# 06 — Dialect awareness

EXPRESS the standard has editions; Expressir should speak them
explicitly.

## Parts (each ships)

1. Dialect flag: parser + checker accept `dialect: :"10303-11:1994" |
   :"10303-11:2004"` (default 2004). Gating: EXTENSIBLE/BASED_ON/
   GENERIC_ENTITY are 2004-only (1994 corpora exist in legacy
   resources); 1994 rejects them with a dialect note, 2004 accepts.
2. Amendment tracking: the Amd1 change list as a source document;
   edition-sensitive checker notes (`:check_dialect_*`).
3. Corpus pass: run both dialects over the resource slice; mixed
   dialects in one file produce a clear diagnostic.

## Acceptance

- A 1994-era resource schema parses clean under 1994, flags its
  non-1994 constructs under 2004-diagnostics mode.

## Status: done

- Part 1 (dialect flag): `Expressir::Express::Dialect` normalizes the
  `:"10303-11:1994"` / `:"10303-11:2004"` editions (also "1994",
  "2004", full strings) and rejects anything else with
  `InvalidOptionError`. `Parser.from_file/from_files/from_exp` accept
  `dialect:` (default 2004) and validate it; the grammar parses the
  union of both editions so a model can be inspected under either.
  `Checker.new(repository, dialect:)` emits the edition notes:
  under 1994, `:check_dialect_2004_only` (error) for EXTENSIBLE,
  BASED_ON, GENERIC_ENTITY and SUBTYPE_CONSTRAINT declarations; under
  2004, `:check_dialect_deprecated` (warning) for the edition-1 inline
  subtype-constraint syntax that Annex K deprecates in favour of
  SUBTYPE_CONSTRAINT. Notes are emitted only when a dialect is passed,
  so the default checker report is unchanged.
- Part 2 (amendment tracking): the audited change list is a checked-in
  source document at
  `spec/fixtures/dialects/iso-10303-11-2004-changes.yaml`, with the
  clause each construct comes from (8.4.1, 8.4.2, clause 9, Annex K,
  Annex G) and a live example per entry.
  `spec/expressir/express/dialect_spec.rb` asserts every change entry's
  declared note fires under 1994 (or 2004 for the deprecated syntax),
  that no note id is outside `Dialect::NOTE_IDS`, and that the 2004
  examples are accepted under 2004. A 1994-era plain schema produces
  no notes under either dialect.
- Part 3 (corpus pass): a gated `EXPRESSIR_CONFORMANCE` tier runs both
  dialects over the stepmod resource slice (266 files <250 KB), and
  `:check_dialect_mixed` gives one clear diagnostic when a file
  combines 2004-only declarations with edition-1 inline
  subtype-constraint syntax. Installations without the corpus skip the
  tier.
- Limitation recorded: the 2004 text grammar is effectively a superset
  of 1994, so the only edition-1-only signals available to a text
  checker are the Annex K deprecations; EXPRESS-G notation and the
  enumeration-ordering semantics deprecated by Annex K have no text
  form to flag.
