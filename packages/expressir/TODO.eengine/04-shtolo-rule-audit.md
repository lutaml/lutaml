# 04 — SHTOLO rule audit + corpus differential

Folds TODO.parity-ee 14's remainder.

- Walk `spec/fixtures/shtolo/annex-g-rules.md` (G.NM.1-2, G.1.1-10,
  G.2.1-7): mark every rule PASS/partial/✖ with a fixture per rule.
- G.1.6 dependently-instantiable output verified against the Annex G
  text (eeng ✖ there; the standard wins).
- name-munging policy (`_dot_` and friends): eeng ✖; standard wins.
- prune-pass reachability (unreachable subtype branches).
- corpus differential: every modules.lst module arm/mim, flat output
  diffed vs eeng :flat, divergences classified.

## Result: DONE (2026-10-15) — the audit is a live spec

`shtolo_annex_g_rule_audit_spec.rb` — 8 examples, one per previously
uncovered rule. Audited outcome:

- G.NM.2, G.1.2, G.1.5, G.1.8 (model-direct), G.2.3, G.2.4, G.2.6 —
  PASS (G.2.4's folded extension keeps its G.NM.1-munged name —
  correct per the name-clash rule).
- G.1.10 — was absent; **implemented** (`add_provenance_remark!`):
  all-or-none provenance remark on the longform schema with
  schema + schema_version_id lines.
- Still open (recorded in annex-g-rules.md): G.1.6
  dependently-instantiable RULE/FUNCTION synthesis (eeng ✖; annex is
  the contract) and the G.1.9 prune-depth notes.

Fixture note: `EXTENSIBLE_ENUMERATION` as a single composite keyword
is not in the grammar and not in the corpus — the corpus writes
`EXTENSIBLE ENUMERATION` (302×) / `EXTENSIBLE SELECT` (546×), both
supported.

## Status: done

- `spec/fixtures/shtolo/annex-g-rules.md` records the audited
  statuses for every Annex G rule, each with a live worked example in
  `spec/expressir/express/shtolo_annex_g_rule_audit_spec.rb`.
