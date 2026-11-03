# 19 — End-state architecture: Expressir in Rust, bound to metanorma via lutaml-model

**Question (2026-09-23): should Expressir ultimately be in Rust, bound to
metanorma via lutaml-model?**

**Answer: yes as a direction, no as a rewrite.** The end state is
*Rust engine, Ruby presentation* — reached in three milestones, not by
porting everything at once. The binding to metanorma goes through
lutaml-model's Liquid Drop layer, which is exactly the seam that
already works (expressir#255, #319, #421, #426).

## Current state (v2.4.9, measured)

```
.exp ──► parsanol-rs 0.8.8 (parse, wire tree)
          └─► expressir_core ext (batch, EXSCS1 artifact, warm start)
                └─► instantiate → Expressir::Model (lutaml-model, Ruby)
                      └─► Checker / Shtolo / formatters (Ruby semantics)
                            └─► Liquid Drops ──► metanorma / suma
```

- Parse is Rust and fast (SRL cold 36 s CPU, SMRL 558 s CPU / 1448
  schemas); parsanol 0.8.8's selective memoization is adopted.
- The measured floor is now the **wire→Ruby-object hydration**
  (71 % of warm CPU) and the overlays (29 %). Rendering (metanorma)
  touches a small fraction of the model.
- Semantics (Checker subset, SHTOLO with the 50-module eengine
  differential, PrettyFormatter, SMRL XML) live in Ruby, eeng-parity
  validated, with Ruby CI harnesses.

## Options considered

**A — Status quo+.** Rust keeps parse+artifact; all new semantics
(Checker catalog, mapping validation) land in Ruby. No rewrite risk,
parity harnesses stay, but the hydration floor remains and the Rust
surface stays private.

**B — Lazy binding (the recommended milestone).** Keep the Ruby model
as the canonical object model for feature work, and add a READ path
that serves metanorma directly from Rust-held compiled-set data:
expressir_core exposes accessors over the loaded set (schema by id,
kind listings, field reads), and a lutaml-model Drop proxies them on
demand — rendering never instantiates the full object graph.
lutaml-model keeps ownership of mappings/serialization/Drop
integration; the Drop becomes the literal "Expressir in Rust bound to
metanorma via lutaml-model".

**C — Full Rust Expressir.** Model + semantics in Rust; Ruby keeps
only Drops and CLI glue; publish expressir-rs on crates.io; unlock
non-Ruby consumers (standalone binary, WASM). Rejected for now: it
re-implements eeng-validated semantics with parity risk, doubles CI,
and metanorma still needs a Drop/FFI layer — the boundary cost moves,
it does not disappear.

**Decision: B now; C deferred behind explicit triggers**
(a non-Ruby consumer materializes; the Ruby semantic layers become a
measured bottleneck — they are not today; or crate publishing is
wanted for supply-chain reasons independent of consumers).

## Milestones

### M1 — rev-pinned core dependency (supply chain, one line)
The ext pins `expressir-rs = { git …, branch = "main" }`; a released
gem can pick up a shifted core. Pin `rev = "<sha>"` per expressir
release (2.4.8 ↔ today's expressir-rs main), bump per release.

### M2 — lazy Drops for the metanorma hot path
1. expressir-rs: read accessors over the loaded compiled set
   (`schema(id)`, kind listings, per-declaration field reads,
   remark/refs overlay application in place).
2. expressir_core: magnus wrappers returning primitives.
3. Ruby: `LazySchemaDrop` (lutaml-model #319 custom Drop, the same
   seam as #255/#426) implementing id / declaration listings / source
   faces via the accessors.
4. Gates: suma-style schema-doc pages render output-comparable with
   the eager path on a fixture corpus; warm page-render benchmark;
   SMRL warm-start CPU target ≤ 30 % of today's 128 s for the
   read-only path.

### M3 — semantics placement rule (standing)
New semantic features land in Ruby **unless** they are
parse-adjacent or graph-scale (then Rust in expressir-rs). The
Checker catalog (12) and mapping validation (18) stay Ruby; SHTOLO
stays Ruby with its eengine differential as the gate.

### M4 — trigger review for option C
Reassess on any of: a non-Ruby consumer request; hydrate/overlay CPU
re-emerging as the top cost after M2; a crates.io publication ask.
M2's accessors are exactly the seed of C's public API — nothing in B
is throwaway.

## What lutaml-model owns in every option

The mapping DSL (yaml/json faces — incl. the #88 `mapping.yaml`
reader), Liquid integration (#319 Drops), artifact serialization —
the binding contract between the engine and metanorma. Rust never
duplicates it.
