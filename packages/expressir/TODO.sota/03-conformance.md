# 03 — Conformance: measure against the standard's own yardstick

## Parts (each ships)

1. Part 21 conformance corpus: extract the conformance-requirement
   examples from the detached ISO 10303-21 source (annexes + body
   worked examples) into fixtures; a gate spec runs the P21
   reader/validator over every positive fixture (clean) and every
   negative fixture (the intended note id, only).
2. Grammar-conformance harness: property-based generation from the
   ISO 10303-11 Annex A/B productions (finite fragments first:
   declarations, then expressions). Invariants: parse→format→parse
   idempotence, formatter output re-parses, ill-formed input rejected
   with a diagnostic (no silent recovery on the strict faces).
   Promoted to a nightly CI tier.
3. G.1.7 closure: the BASED_ON enumeration-chain corpus fixture —
   the last unaudited Annex G rule (annex-g-rules.md table tail).

## Acceptance

- `rake conformance` (or the spec tier) green; negatives fail with
  exactly the intended note, positives with zero notes.

## Status: done

- Part 1 (Part 21 conformance corpus): the ISO 10303-21 detachment
  examples are extracted to `spec/fixtures/p21/conformance/`:
  annex-e-0/1 (named data sections), annex-h-0 (the worked exchange
  structure, 13 instances), annex-i-0/1 (ANCHOR/REFERENCE), annex-j-0
  (constants). `spec/expressir/p21/parser_conformance_spec.rb` parses
  every positive fixture with zero notes and asserts the intended
  failure for the forms this ladder does not implement yet (annex E
  named sections and `..`, annex I ANCHOR/REFERENCE, annex J
  constants/`....` and STEP-21-ED2 extended literals) — they fail
  loudly, not silently. Malformed negatives are rejected.
- Part 2 (grammar-conformance harness):
  `spec/expressir/express/formatter_roundtrip_conformance_spec.rb`
  asserts parse → format → parse structural idempotence over a fixture
  slice, over generated fragments (Annex A/B production levels:
  expression → simple_expression → term, declarations, arrays, QUERY,
  unary/logical/relational forms, deterministically seeded), and
  rejection of terminators removed from generated input. The
  `EXPRESSIR_CONFORMANCE=1` tier round-trips the full stepmod resource
  slice (<250 KB; 266 files on this box) and `rake conformance` runs it; the
  nightly `conformance.yml` workflow checks out the sparse stepmod
  corpus. En route the generator found a formatter bug: nested unary
  minus formatted as `--x`, which EXPRESS reads as a comment; unary
  operands are now parenthesized. Generator lesson: relational
  operators are non-associative, and reserved words (e.g. `VALUE`)
  cannot name parameters.
- Part 3 (G.1.7 closure): the BASED_ON enumeration-chain example is in
  `shtolo_annex_g_rule_audit_spec.rb`; every Annex G rule now has a
  live worked example and the audit table has no unaudited tail.
