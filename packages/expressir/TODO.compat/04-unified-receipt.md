# 04-unified-receipt — Unified repository receipt

 one deterministic artifact binding schema validation, instance dataset validation and mapping validation (the three shipped validators) with digests, versions and per-rule verdicts; structured for signing. Acceptance: one manifest drives one receipt; byte-identical reruns; signing-ready canonical JSON.

## Status: done

- `Expressir::Receipt`
  (`lib/expressir/receipt.rb`): one workspace manifest
  (`Expressir::Receipt::WorkspaceManifest`, lutaml-model key-value
  mapping) drives one receipt binding the three shipped validators —
  schema (`Expressir::Express::Checker`), instance datasets
  (`Expressir::P21::Validator` over `DatasetManifest`s) and module
  mappings (`Expressir::Mapping` links/refpaths/rules) — with SHA-256
  digests of every consumed input, the generator version, and per-rule
  verdicts.
- Canonical, signing-ready bytes: recursively sorted object keys, no
  insignificant whitespace, no timestamps, manifest-relative paths —
  `Receipt.generate` output is byte-identical across reruns and
  checkouts; signatures cover the canonical serialization (declared in
  the receipt's `canonicalization` field).
- CLI: `expressir receipt MANIFEST [-o FILE]` — exits 1 when the
  receipt reports errors.
- Specs: `spec/expressir/commands/receipt_spec.rb` — one manifest →
  one receipt covering all three validators; byte-identical reruns;
  canonical byte form (regenerated == stored); error path exits with
  the receipt still written.
