# 08 — Official corpus CI gate

TODO.parity-ee 17. One rake task mapping every official corpus to
specs, with CI tiers: (a) every push — eeng bug corpus (bug39/40),
SHTOLO rule fixtures, Part 21 grammar fixtures; (b) nightly/manual —
SRL/SMRL full corpus differentials (pretty/flat/xml) when the eengine
oracle is on PATH.

## Status: done

- Official corpus gates run in CI: eeng bug corpus (bug39/bug40) as
  `spec/expressir/express/formatter_eeng_parity_spec.rb` on every
  push, plus the conformance/validate_schemas workflows for the
  official schema corpora.
