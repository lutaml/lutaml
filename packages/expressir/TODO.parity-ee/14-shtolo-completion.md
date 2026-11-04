# 14 — SHTOLO completion (expressir#32, Annex G)

## Goal

Finish `Expressir::Express::Shtolo` to full Annex G conformance and
close the eeng differential over the whole corpus. Current state:
G.1 + G.2 stages implemented (522 lines), suite green (10 examples),
`extenders:` :all/:none matches the eeng-default split.

## Remaining work

1. **Rule audit**: walk `spec/fixtures/shtolo/annex-g-rules.md`
   (G.NM.1-2, G.1.1-10, G.2.1-7) and mark every rule PASS/partial/✖
   in the file; a fixture per rule. Known-thin areas from the audit:
   - G.1.6 dependently-instantiable rule output (function + WHERE
     wiring) — verify against Annex G text, not eeng (eeng ✖).
   - name-munging policy (`_dot_` and friends) — eeng ✖; standard wins.
   - prune pass reachability (unreachable subtype branches).
2. **Corpus differential**: for every module arm/mim in modules.lst,
   compare our flatten output to `eengine --flat` (eeng default =
   `extenders: :none` shape); classify divergences
   standard-conformant vs bug. Feed the mismatch corpus into specs.
3. **Scale**: SMRL full set flatten over the compiled-set warm model;
   memory ceiling documented.
4. **CLI**: `expressir shtolo MANIFEST -o longform.exp` (root schema
   + closure resolution reuses ParityInputs).

## Acceptance

- Every Annex G rule has a green fixture.
- Corpus differential: zero unexplained diffs; every explained
  divergence documented in `parity-matrix.md`.
- SMRL flatten completes; output parses under the 1994 profile.

## Test cases

- annex-g-rules.md fixtures; eeng `docs/issues/bug39` shtolo outputs
  (old-vs-new vs stepcode exppp); `scripts/qual-*.sh` loops;
  `pretty-test.sh` ap209/210/242 × arm/mim shape checks.

## Release checkpoint

One PR per coherent slice (rule audit + fixtures; differential gate;
CLI), patch releases as each merges.
