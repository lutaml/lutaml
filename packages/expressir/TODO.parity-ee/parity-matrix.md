# eeng ↔ expressir parity matrix (2026-09-21)

Reference: `~/src/external/exp-engine-engine` (eengine-5.0.20-Beta1).
Audited files: kernel/{find-declaration,find-entity,find-type,
resolve-interface,resolve-object,resolve-ref,references,schema-search,
interfaces,compute-inheritance,supertypes,derive-attrs,
inverse-attrs,check,compare,dot-graph}.lisp; plugins/p11/{schedule-*
,resolve-declaration,cleanup-interface,wo-*}.lisp.

## 1. Name resolution ladder (kernel/find-declaration.lisp:125-172)

eeng's schema-scope restriction ladder for `find-declaration`:

```
nil        = :use-from
:local     → own declarations + constants only
:use-from  → :local OR :use-only
:use-only  → walk USE FROM interfaces only, transitively, each in
             :use-from scope (so USE visibility is transitive)
:all-iface → :local OR all interfaces (USE and REFERENCE), transitively
cycle guard → *schema-path*: schema already on path ⇒ nil
```

Per-kind restrictions (`resolve-interface.lisp:30-66`):
- USE FROM resolves **type + entity only**.
- REFERENCE FROM resolves constant/entity/function/procedure/type.
- Unresolved resource ⇒ hard **error** `"Resource '~A' not found"`.

**expressir today:** `ModelElement#find` climbs parent scopes through
`children_by_id`; `Schema#children` = `interfaced_items + safe_children`
where `interfaced_items` is **single-hop** (own interfaces only, no
transitivity), and the resolver never errors on unresolved resources.
Our `find` also treats REFERENCE and USE identically (no visibility
tiering), and has no cycle guard (schema interface cycles loop until
the memo fills — the memo makes this safe in practice, not by design).

**Gaps:** (a) transitive USE visibility — item visible through a chain
of USEs is invisible to our single-hop lookup; (b) USE/REFERENCE
visibility tiering absent; (c) no unresolved-resource diagnostics;
(d) no cycle guard by construction. Fix tracked in TODO 06.

## 2. Load scheduling (plugins/p11/schedule-*.lisp)

eeng: `schedule-load` (two-pass parse), `schedule-interfaces`
(one method per session kind: double-stepmod keeps trl/ref schema
sets — schema1/schemata1 = trial, schemata2 = reference), recursing
per interface symbol → find/load the foreign file via the stepmod
directory layout, then `schedule-resolve` → `resolve-declaration` per
schema with `*schema?*` dynamic scope (:trl-schema / :ref-schema).

**expressir today:** `from_files` (batch + compiled set), repository
flat over all files; no trl/ref duality (we never compare two
specification universes); interface targets located by name at resolve
time through the repository (single-hop, see §1).

**Verdict:** structural difference, not a bug — our repository model
subsumes their session model for everything except `--compare`
(two-universe schema comparison, kernel/compare.lisp, unported; TODO
07 candidate).

## 3. Entity computations (kernel/compute-inheritance.lisp,
derive-attrs.lisp, inverse-attrs.lisp, supertypes.lisp,
explicit-attrs.lisp)

eeng **materializes** inherited attributes onto entities:
explicit attributes from the full supertype closure, derived attrs,
inverse attrs, subtype/supertype links — used by `--validate`,
population checks, and SHTOLO's generalized-attribute handling
(Annex G.2.6 needs exactly these).

**expressir today:** nothing materialized; consumers walk the
supertype closure themselves (our item graph does this for edges, not
attributes).

**Gaps:** inherited-explicit-attribute flattening, derived/inverse
closures. Needed by 05 (G.2.6 select synthesis) and 07 (checks).
TODO 05 scope.

## 4. Semantic checks (kernel/check.lisp, 835 lines)

check-p11 methods per node type: schema-level (interface resource
existence, per-kind resolution rules), entity (attribute redeclare
compatibility, inverse target/entity/inverse-attr existence, derive
aggregation rules), function/procedure/rule parameters, subtype
constraints, types. Check severity/notes via check-notes.lisp.

**expressir today:** `RepositoryValidator` (interface-level only) +
`validate ascii` CLI. Gap tracked in TODO 07.

## 5. Writers (plugins/p11/wo-*.lisp)

| eeng | semantics | expressir |
|---|---|---|
| wo-pretty | normal encoding, 2-space indent | Formatter clean mode — parity specs landed (bug39/40) |
| wo-flat | `:flat` encoding, downcased symbols, typeof-option banner | 05 (Annex G — note eeng's flat KEEPS 2003 constructs: partial) |
| wo-list | declaration listing | 09 |
| wo-smrl-xml | `<concatenated_express_file_content_list>` index for longform/concatenated modes | 09 |
| wo-lexp | lisp S-expression dump | not planned (internal debugging) |

## 6. Bugs found by this audit

- **expressir#373** — Ruby parse path corrupts small USE FROM schemas
  (<~70B, non-monotonic; core path correct). Found by the concatenator
  fixtures; `dependency_resolver_spec` failures on main are the same
  root cause. Fixed by the #371/#370 stack.
- eeng partial Annex G coverage — documented in
  `spec/fixtures/shtolo/annex-g-rules.md` (eeng is a partial oracle;
  the annex is the contract).
