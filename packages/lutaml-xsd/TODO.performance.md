# TODO.performance — measured speed on the fastest Ruby XML engine

Goal: stay the fastest, prove it continuously, and adopt every new engine
surface as moxml/leptris ship it.

## Engine integration maturation

- [x] Track https://github.com/lutaml/moxml/issues/410 — FIXED and
      RELEASED (moxml 0.5.149, moxml PR #411). lutaml-xsd now locks
      0.5.149: `Schema#content_valid?` answers correctly on leptris and
      the engine content-seam specs run live.
- [x] Content delegation verified live: engine answers true/false for
      matching/mismatching child sequences (engine_context_spec + the
      formerly gated content-model rule specs).
- [ ] Adopt moxml `Plan`/`StructPlan` materialization for the hot
      parse path if lutaml-model exposes seams for it (profile first)
- [ ] Engine error payload richness: once line/column/path are stable
      across adapters, surface them in CLI output and the SPA findings UI
      — PARTIAL: CLI JSON already carries code/message/severity/
      location/line_number/context (verified 2026-10-21); SPA wiring
      rides TODO.docs-spa.md

## Benchmarks

- [x] In-repo benchmark suite (`benchmark/engines.rb` + `rake
      benchmark:engines`): engine parse/xpath/serialize, pipeline parse,
      schema to_xml, compiled-schema validation
- [x] Baseline table: leptris vs nokogiri adapter (2026-10-20, Ruby 3.4.8,
      arm64-darwin, 10.8 KB corpus converted from
      metanorma-model-iso-grammars/bsi.rnc under rng 0.3.7 — corpus is
      SMALL because rng 0.3.7 partially resolves the include tree;
      re-run after the rng 0.3.9 recalibration for the full corpus):

| measurement | leptris | nokogiri |
|---|---|---|
| engine_parse | 0.3 ms | 0.4 ms |
| engine_xpath_elements | 0.9 ms | 0.4 ms |
| engine_serialize | 0.7 ms | 0.1 ms |
| pipeline_schema_parse | 274 ms | 377 ms |
| pipeline_schema_to_xml | 224 ms | 223 ms |
| engine_xsd_compile | 0.1 ms | n/a (SyntaxError on rng-0.3.7 corpus) |
| engine_xsd_validate | 0.0 ms | n/a |

  Caveat: per-op values are noisy run-to-run (0.1–12 ms spread observed)
  on a small corpus; the harness is the deliverable, numbers firm up on
  the post-recalibration corpus.
- [ ] CI-optional benchmark run (manual dispatch) with trend notes —
      no PR-blocking perf gates yet

## Profiling targets

- [ ] SPA generation memory profile on 100+ schema corpora — DEFERRED:
      needs the post-recalibration corpus (TODO.cleanup.md) and the SPA
      pillar (TODO.docs-spa.md); the marshal-cleanup code is already in
      place
- [ ] `EngineContext.compile` cost on multi-schema repositories —
      DEFERRED: measured at 0.1 ms/compile on the benchmark corpus (well
      below noise); revisit only when the full-include corpus changes the
      picture
- [ ] XmlNavigator walk cost on deep instance trees — DEFERRED: no
      evidence of a hotspot yet; take it with the rule-engine wiring,
      which is the walker's main consumer

## moxml Builder DSL profile (2026-10-21, reported to moxml sota/04)

rng's converter drives `Moxml::Builder`; the same 500-define synthetic
tree through the same DSL:

| path | time |
|---|---|
| Moxml Builder + nokogiri adapter | 0.059 s |
| Moxml Builder + leptris adapter | 0.463 s |
| direct `Leptris::XML::Builder` | 0.007 s |

The ~8x gap is in moxml's leptris builder-face interaction (create_tag /
method_missing / face flush), not the binding — the DSL through the
nokogiri adapter is only ~2x native Nokogiri's builder. moxml's scoreboard
covers the mutation API, not the Builder DSL; this is offered as a row +
profile lead for the moxml perf branch. Work belongs in moxml, not here.

