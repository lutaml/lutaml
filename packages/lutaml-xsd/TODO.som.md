# TODO.som — schema object model completeness (XSOM parity)

Goal: the Ruby SOM must answer every structural question XSOM can, with
XSD 1.1 constructs layered on.

Status 2026-10-20: DEFERRED as a pillar. Reason: every item here is a
specification-parity design cycle (component resolution semantics,
derivation graphs, 1.1 constructs), and the conformance gap register
(rule-engine wiring first) and the release-gated rng recalibration are
higher-leverage prerequisites. Track this file as the design backlog; do
not start mid-cycle.

## Parse-side completeness

- [ ] `xs:redefine` semantics (redefinition chains, component shadowing)
      — DEFERRED: needs a component-resolution design note first
- [ ] Chameleon includes (namespace adoption rules) — DEFERRED: verify
      current behavior against the rng include fixes, then design
- [ ] Substitution group closure and membership enumeration on the model
      — DEFERRED: pairs with the conformance substitution-group gap
- [ ] `xs:group` / `xs:attributeGroup` reference resolution including
      redefined groups — DEFERRED (same design cycle)
- [ ] Complex type derivation graph: extension/restriction chains,
      `{base type definition}` reachability — DEFERRED: the type-hierarchy
      analyzer exists; extending it into a full derivation graph is the
      design entry point
- [ ] Simple type facets carried losslessly — DEFERRED: covered
      opportunistically by the JSON Schema exporter tests; a dedicated
      round-trip matrix should come with the recalibration

## Query surfaces

- [ ] Structural queries via moxml XPath where trees are involved —
      DEFERRED: profile first (EngineContext already avoids Ruby walks)
- [ ] `SchemaRepository#types_in_namespace` deterministic ordering and
      stable public docs — DEFERRED: small, take it with the next
      repository-touching PR
- [ ] Type hierarchy export (DOT/mermaid) into the SPA — DEFERRED: needs
      the SPA work in TODO.docs-spa.md

## 1.1 constructs (behind `version: "1.1"`)

- [ ] `xs:assert` / `xs:assertion` model + evaluation hooks — DEFERRED:
      XSD 1.1 strategy decision needed (engine support vs pure Ruby)
- [ ] `xs:alternative` conditional types; `openContent` modes — DEFERRED
      (same 1.1 strategy)
- [ ] `xs:override` and `xs:defaultOpenContent` — DEFERRED (same)
