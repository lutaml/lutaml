# TODO.docs-spa — comprehension SOTA: interactive, live-validated documentation

Goal: leapfrog static commercial doc-generators (Oxygen/Altova) with an
interactive corpus browser where the documentation *executes*.

Status 2026-10-20: DEFERRED as a pillar. Reason: the SPA features below
need the frontend development loop (`rake build_frontend`, Vue dev server)
and a backend seam decision (CLI vs HTTP). The validation core these
features depend on is ready (EngineContext + `engine_validation` +
Conformance runner), so the UI work can start against a stable base. The
one prerequisite wiring — rule-registry gaps surfacing as findings — is
tracked in TODO.conformance.md.

## Live validation playground (the killer feature)

- [ ] SPA page: paste/upload an XML instance → validate against the loaded
      package (engine + rule stack via a CLI/HTTP seam) → findings with
      line/column/path — DEFERRED: backend seam decision + frontend build
      loop
- [ ] Click-through: finding → schema component page — DEFERRED (needs
      the playground first)
- [ ] Instance tree view with per-node validity — DEFERRED (needs
      element-path findings in the UI; engine already reports paths)

## Navigation & comprehension

- [ ] Global search across types/elements/attributes/groups — DEFERRED:
      the search index exists (`build_index`); ranking design + UI work
- [ ] Usage navigation matrix for attributes and groups — DEFERRED:
      liquid methods pattern exists; extend `used_by` coverage first
- [ ] Type hierarchy graph in the SPA — DEFERRED (pairs with TODO.som.md)
- [ ] Dependency graph page — DEFERRED

## Evolution

- [ ] Schema diff between package versions — DEFERRED: structural diff
      design needed (component identity across versions)
- [ ] Coverage view wired to `coverage_analyzer` — DEFERRED

## Polish

- [ ] SPA generation performance on large corpora — DEFERRED until the
      post-recalibration corpus exists (TODO.performance.md)
- [ ] Accessibility pass on the SPA — DEFERRED (rides the next UI change)
- [ ] Nightly demo package regeneration in CI — DEFERRED: cimas-owned
      workflow; needs an owner decision on schedule
