# 11 — Import the Express Engine test suite

**Status: NOT STARTED**

## Goal

Fully import eeng's tests — their release-suite scripts, the bug
corpus, and the reference documents that define pass/fail — as
executable RSpec feature specs and regression fixtures in expressir.
Nothing in their suite should remain unrepresented.

## Inventory (verified 2026-09-21)

eeng has no formal test framework (`tests/` is a README describing an
unrealized Makefile suite); the suite is:

### CLI drivers — `scripts/*.sh` (14)

| script | drives | our target operation |
|---|---|---|
| `qual-arm.sh`, `qual-mod.sh` | per-module qualification loop (arm/mim × every qualify.sh op) | 04, 05, 07-10 end-to-end specs |
| `qual-res.sh` | same over `qualify-res.txt` resources | idem, resource side |
| `pretty-test.sh` | `--pretty` ap209/ap210/ap242 × {arm,mim} × {shortform,longform} | 08 formatter specs |
| `ap210.sh` | the 2.5MB long-form giant, pretty × 4 modes | 08 scale spec |
| `test-tt.sh`, `test-tt1.sh` | `--xml` arm/mim shortform + Saxon HTM conversion + regenerate-exp compare | 09 (XML chain) |
| `build-xml.sh` | XML builds over the whole `modules.lst` + `resources.lst` | 09 corpus spec |
| `test.sh` | ad-hoc resource XML/HTM driver (kinematic schema) | 09 |
| `scan-res.lisp` | resource corpus scan | 07 check corpus |
| `kevin.sh`, `veronique.sh`, `copy-mod-xml.sh` | person-named scratch drivers | triage: keep as scenarios or drop with rationale |

Each script's eeng CLI matrix (`-mode {arm,mim}_{shortform,longform,
concatenated}` `-stepmod` `-schema` `--pretty/--xml/--flat/--dot
--check`) maps 1:1 onto our planned operations — the flag matrix
becomes our spec matrix.

### Bug corpus — `docs/issues/`

- `bug39-Greedy-Parens.txt` — **shtolo fixture**: contains "results
  of old shtolo and stepcode exppp" vs "results of new shtolo"
  outputs; doubles as a differential vs stepcode exppp.
- `bug40-Pretty-Expressions.txt` — pretty-printer expression cases.
Both become regression specs with the literal inputs embedded.

### Reference documents — `docs/` (define pass/fail)

- `shtolo_converting_STEP_short_listings_to_annotated_listings_libes.pdf`
  — the SHTOLO paper (short listings → annotated listings); required
  reading for 01/05 semantics.
- BNF grammars: `iso-10303-11--2004{,-raw}.bnf`, `iso-10303-14*.bnf`,
  **`iso-10303-21--{1994,2002}.bnf`** (Part 21!), `xml.bnf`,
  `patch_schema.bnf` — grammar cross-checks (05's 1994 profile; the
  Part 21 BNFs feed the future p21 parser).
- `express_model.dtd`, `module.dtd` — the DTDs their XML emits (09's
  structural contract).
- `qualify.txt`, `interfaces.txt`, `interface-notes.pdf` —
  qualification + interface semantics notes.
- `00check.txt` (repo root) — check.lisp design notes → 07.

## Steps

1. Copy the durable assets into the repo: scripts verbatim under
   `spec/fixtures/eeng/scripts/` (provenance header), bug corpus under
   `spec/fixtures/eeng/issues/`, DTDs + BNFs under
   `spec/fixtures/eeng/grammar/` (license is MIT-style per eeng
   headers — verify and record attribution).
2. Translate the CLI matrix into RSpec feature specs
   (`spec/expressir/eeng_parity/`): one describe per driver family,
   one example per (schema × mode × operation), corpus-scaled ones
   tagged `smrl`.
3. Port bug39/bug40 as literal regression specs now (they need only
   parser + formatter, both of which exist).
4. Extend 03's oracle harness to emit/refresh the expected outputs
   these specs consume.

## Acceptance

Every driver row and both bugs have a corresponding spec (or a
documented drop rationale); `smrl`-tagged parity suite green against
the 03 golden corpus.
