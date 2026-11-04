# 07 — Reference artifacts: the citable Expressir

The academic endgame — make the implementation provable and citable.

## Parts (each ships)

1. Grammar cross-walk: rule-by-rule table, parsanol grammar rule ↔
   ISO 10303-11 Annex A/B production, with divergences (extensions,
   recoveries) classified — rendered into docs/ and kept in sync by a
   spec that fails when a grammar rule lacks a row.
2. Property-based corpus testing as a published nightly tier (03's
   harness, trended: parse rate, diagnostic rate, idempotence rate).
3. Published guides: one doc per subsystem (checker + note-id
   catalog, shtolo + annex-g-rules linkage, p21, evaluator, lsp),
   generated where possible from the model (note-id catalog from the
   Checker's constants).

## Acceptance

- docs/ builds with the cross-walk and guides; the sync spec is part
  of the default suite.

## Status: done

- Part 1 (grammar cross-walk): `Expressir::Reference::GrammarCrosswalk`
  reads the audited mapping in
  `lib/expressir/reference/grammar_crosswalk.yml` and renders
  `docs/_guides/reference/grammar-crosswalk.adoc`. All 250 parsanol
  rules are accounted for: 207 aligned with the same-named Annex A
  production (CamelCase normalized to snake_case), 8 decomposed into
  PEG sub-rules, 30 literal operator/delimiter tokens, 4 lexical
  whitespace/delimiter rules and 1 PEG-internal keyword guard. The 12
  Annex A productions without a dedicated rule are listed and
  classified (remark productions are handled by
  RemarkScanner/RemarkAttacher; the rest are PEG lookaheads or
  character classes). The Annex A snapshot lives at
  `spec/fixtures/reference/annex-ab-productions.txt`. The spec fails
  when a grammar rule lacks a row, a row names a missing rule/status,
  an Annex production is unaccounted for, or the published guide is
  stale; regenerate with `rake reference:crosswalk`.
- Part 2 (trended nightly tier): `Expressir::Conformance::Trend`
  measures a corpus slice — file count, parse rate, format-idempotence
  rate, diagnostic rate (Checker notes per parsed file), error/warning counts and per-note-id counts —
  and writes a JSON artifact. `rake conformance:trend` runs it over the
  stepmod resource slice; the nightly `conformance.yml` workflow runs
  it after the round-trip tier and uploads `conformance-trend.json`.
  Spec: `spec/expressir/conformance/trend_spec.rb`.
- Part 3 (published guides): `docs/_guides/reference/` now carries an
  index plus subsystem guides — checker (with the generated note-id
  catalog, `rake reference:notes`), Part 21, SHTOLO/Annex G (linked to
  `annex-g-rules.md` and the audit spec), evaluator, and the language
  server. The two generated pages are checked for staleness by
  `spec/expressir/reference/*_spec.rb`, which run in the default suite.
  The docs site build (`.github/workflows/docs.yml`) covers the new
  pages.
