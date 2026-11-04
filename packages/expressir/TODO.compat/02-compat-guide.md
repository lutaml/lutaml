# 02-compat-guide — Compatibility guide, divergence register (D-NN) and the expressir doctor workspace assessment

 docs/_guides/compat/ gets the per-command Rosetta table and exit-code contracts; doctor reads an existing toolchain workspace (corpus paths, batch scripts, configs) and emits a readiness report plus a starter manifest. Acceptance: doctor on the shipped corpus fixtures reports every fixture as ready; the register cites every known divergence.

## Status: done

- Divergence register: `docs/_guides/compat/interchange.adoc`
  (D-01 corpus header tolerance, D-02 remark-only files, D-03
  schema.changes Moxml emission) with the linkage guard
  `spec/expressir/compat/divergence_register_spec.rb` — entries must
  cite existing specs, ids contiguous.
- Compatibility guide: `docs/_guides/compat/toolchain.adoc` — the
  per-command Rosetta table (invocation, output, pinning spec) and
  exit-code contract.
- `expressir doctor DIR [-o MANIFEST]`
  (`lib/expressir/commands/doctor.rb`): scans a workspace for
  schemas (.exp), instance datasets (.p21) and mapping files
  (mapping*.yaml), probes each with the shipped parsers, prints the
  readiness report (ready/UNREADABLE per file), and optionally writes
  a starter schema manifest. Spec:
  `spec/expressir/commands/doctor_spec.rb`.
