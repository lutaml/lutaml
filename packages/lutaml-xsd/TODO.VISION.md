# TODO.VISION — lutaml-xsd: purpose audit and the SOTA thesis

Last audited: 2026-10-20.

## The purpose (audit answer)

lutaml-xsd exists to make XML Schema corpora **legible, governable, and
documentable**. Everything in this repository serves one thesis in three
movements:

1. **Ingest** — any real-world schema corpus becomes a first-class Ruby
   object graph: XSD 1.0/1.1 and RNG/RNC, with imports/includes/redefines,
   chameleon schemas, network-resolved schemaLocation, broken documents —
   normalized into a namespace-managed, packageable (`​.lxr`) repository.
2. **Understand** — a complete Schema Object Model plus the tools of
   comprehension: type search, dependency graphs, cross-references,
   coverage analysis, SPA documentation, SVG diagrams. A corpus you can
   *read*, not merely parse.
3. **Govern** — instance validation (Ruby rule engine + native engine via
   Moxml::XSD), package conflict detection/resolution, and bridges to other
   model worlds (Liquid/LutaML, JSON Schema). A schema becomes a living
   contract, and its documentation becomes executable.

The differentiating claim (no SOTA tool does all three): **schema
comprehension at corpus scale, wired into a model-driven documentation
pipeline** (LutaML/Metanorma), on the fastest XML engine available to Ruby
(moxml → leptris).

## What SOTA means here (the benchmarks we accept)

- **Validator conformance**: the W3C XML Schema Test Suite (and the legacy
  Sun/MSV collections) are the canonical benchmark; Xerces-J (1.0) and
  Xerces2/Scala.xml (1.1) are reference implementations. Conformance is a
  NUMBER — pass-rate against that suite. See TODO.conformance.md.
- **Schema comprehension**: commercial SOTA is Oxygen XML / Altova doc-gen
  (static). Academic SOTA is schema summarization/visualization research.
  We leapfrog both with an *interactive* SPA: live validation playground,
  usage navigation, schema evolution diffs. See TODO.docs-spa.md.
- **Performance**: leptris (C99 FFI) + moxml Plan/StructPlan materialization
  is already the fastest Ruby XML stack; we must keep it measured
  (benchmarks in-repo) and adopt new engine surfaces as they land.
  See TODO.performance.md.
- **Object model**: XSOM (Sun) remains the semantic gold standard for a
  schema object model — closure, substitution groups, type unification.
  See TODO.som.md.
- **Interoperation**: bridges to JSON Schema, LutaML cross-paradigm models
  (EXPRESS/UML), and the RelaxNG bridge (rng gem) round us out.
  See TODO.interop.md.

## Pillar index

| Pillar | File | One-line goal |
|---|---|---|
| Conformance | TODO.conformance.md | Measured, growing pass-rate on W3C XSD TS |
| Performance | TODO.performance.md | Fastest, measured, engine-complete |
| Object model | TODO.som.md | XSOM-parity SOM incl. XSD 1.1 constructs |
| Comprehension | TODO.docs-spa.md | Interactive, live-validated documentation |
| Interop | TODO.interop.md | RNG bridge, JSON Schema, LutaML cross-model |
| Cleanup | TODO.cleanup.md | rng 0.3.8 baseline, rng→moxml, hygiene |

Guidance for agents: work pillar by pillar, checkbox by checkbox; every
item lands through a PR with real-object specs; keep this file's audit
current as pillars complete.
## Status 2026-10-20 — first full execution run

Delivered, merged to main:

- **Dependencies**: moxml `~> 0.5.147` pin; leptris in the dev bundle;
  full Moxml migration with zero direct Nokogiri in `lib/` (PR #104, #107)
- **Engine validation**: `EngineContext` + additive `engine_validation`
  phase + lexical/content delegation (PR #107); moxml#410 fixed upstream
  (moxml#411), release-gated for the un-gating step; moxml defect filed
  as moxml#410
- **Reproducibility**: committed Gemfile.lock with all CI platforms +
  `deps:lockfile_check` guard (PR #109)
- **Performance**: `benchmark/engines.rb` + `rake benchmark:engines` with
  leptris/nokogiri baselines recorded (PR #110)
- **Conformance**: corpus (12 classes / 25 checks), Runner, `rake
  conformance`, baseline 80.0% both modes, gap register (PR #111)
- **Ecosystem**: rng gem include-merge fixes (rng#34) and the rng gem's
  Moxml migration (rng#35); `Lutaml::Xsd.parse` restored as the documented
  public entry; XML_SCHEMA exporter (this PR)

Release-gated / owner decisions outstanding:

- moxml release containing #411 (version owner-stated) → un-gate the
  content-seam specs
- rng release containing include fixes + Moxml migration (version
  owner-stated) → recalibrate `RngToXsdConverter` expectations against the
  full-include corpus and bump the lutaml-xsd pin
- A new lutaml-xsd release is the owner's call

Deferred with reasons: see TODO.som.md (XSOM-parity work needs a spec
design cycle), TODO.docs-spa.md (frontend dev loop), TODO.interop.md
(LutaML cross-model contract), TODO.conformance.md rule-depth items
(subsumed by rule-registry wiring, which is the headline rule-engine gap).

## Status 2026-10-21 — rule engine wired, conformance up

- Rule engine wired into production (`RuleRegistry.default`, element-scoped
  dispatch, declaration resolver): pipeline conformance moved from an
  inert copy of engine mode to **34/39 (87.2%)**, ahead of engine mode's
  33/39 (84.6%) — the root-declaration check catches wrong-namespace
  roots the engine skips, and substitution groups, nested sequences,
  union/list, derivation and attribute typing now validate through rules
  with zero false positives.
- moxml 0.5.149 locked: `Schema#content_valid?` live on leptris; the
  engine content-seam specs run un-gated.
- Conformance corpus grew 12 → 19 cases (39 checks).
- moxml Builder DSL profile delivered to the moxml perf workstream
  (leptris face ~8x the nokogiri adapter through the same DSL; direct
  binding builder 65x faster than the current face path).
- CLI JSON validation (`lutaml-xsd xml validate ... --format json`) now
  reports undeclared roots instead of silently passing them — the SPA
  playground's backend seam is functionally complete.

## Status 2026-10-21 (later) — rng 0.3.9 recalibration landed

- rng 0.3.9 released (include fixes + Moxml migration); lutaml-xsd pins
  `rng ~> 0.3.9` and the converter corpus is re-baselined on the full
  include tree (170/13/203/237/44; sections 7/1/1 — `sections` restored
  via bsi's override). The last release gate is closed; remaining items
  in the pillar files are design/owner decisions.
