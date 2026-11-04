# Parity with Express Engine (eeng) — SHTOLO and algorithms

**Status: PLANNED (2026-09-21)**

## Mission

1. **SHTOLO** (expressir#32): SHort-TO-LOng — generate ISO 10303-11:1994
   "long form EXPRESS" (one self-contained schema) from the STEPmod
   multi-schema structure (edition 2: shared files, USE FROM /
   REFERENCE FROM). The normative conversion rules are
   **ISO 10303-11:2004 Annex G** — local sources:
   `~/src/mn/iso-10303-11/sources/sections/ag-single-schema.adoc`.
2. **Concatenation** (expressir#247, metanorma/iso-10303#539): the SHTOLO
   precursor — a dependency-closure concatenation of all interfaced
   schemas into one publication artifact (`.exp`), plus SMRL index.
3. **Validation** of both, against the reference implementation:
   Express Engine (`~/src/external/exp-engine-engine`, Common Lisp),
   whose `qualify.sh` runs the full operation catalog over the exact
   SMRL corpus we already load (`resources.lst`/`modules.lst` ==
   our SRL manifests).

## Reference implementation map

| eeng source | operation (qualify.sh) | task |
|---|---|---|
| `plugins/p11/wo-pretty.lisp` | Pretty Print `.exp` + compare | 08 |
| `plugins/p11/wo-flat.lisp` + `run-op :flat` | **Flatten to long form** | 05 |
| mode `:concatenated` (`kernel/engine.lisp`) | **Concatenate schema** | 04 |
| `plugins/p11/wo-list.lisp` | List declarations | 09 |
| `plugins/p11/wo-smrl-xml.lisp` | SMRL index XML | 09 |
| `kernel/dot-graph.lisp` | Dot interface graph | 10 |
| `kernel/check.lisp` (835 lines) | semantic checks | 07 |
| `plugins/p11/schedule-*.lisp`, `kernel/resolve-interface.lisp` | load/resolution scheduling | 06 |
| `kernel/compute-inheritance.lisp`, `supertypes.lisp`, `derive-attrs.lisp`, `inverse-attrs.lisp` | entity computations | 02/07 |

## What we already have (expressir)

Compiled schema set (batch + EXSCS1 artifact + overlays), repository
indexes + reference graph (37.7k subtype edges, interfaces, closures),
`Schema#interfaced_items`, resolver, formatter (clean/hyperlink),
`RepositoryValidator`, Part 21 parser = **not started** (see 02).

## Task index

01 Annex G rule extraction · 02 eeng algorithm inventory (what we do
differently) · 03 eeng oracle harness · 04 concatenation (#247) ·
05 SHTOLO longform flatten (#32) · 06 interface scheduling parity ·
07 semantic checks port · 08 pretty-print round-trip gate ·
09 SMRL index + listing · 10 interface dot graph ·
11 import the eeng test suite (scripts/ drivers, docs/issues bugs,
SHTOLO paper, BNFs, DTDs)

## Additional eeng assets (via 11)

`scripts/*.sh` — 14 release-suite drivers (qual/pretty/xml/dot);
`docs/issues/` — bug corpus incl. a shtolo old-vs-new differential;
`docs/` — SHTOLO paper PDF, Part 11/14/21 BNFs, XML DTDs,
interface/qualify notes; `00check.txt` — check design notes.

## Phase 2 — full eengine parity (2026-09-22, user-directed)

| # | plan | status |
|---|---|---|
| 12 | full check-p11 catalog port | planned |
| 13 | population / Part 21 validation | planned |
| 14 | SHTOLO completion (Annex G + corpus differential) | in progress |
| 15 | Part 28 XML + SMRL index | done (SMRL index + express2xsd shipped, #276; reference-XSD diff harness escalated to 17) |
| 16 | schema compare & patch | planned |
| 17 | official test-case incorporation | standing structure |

Execution order: 14 (finish Shtolo) → 12 (checks) → 15 (XML index)
→ 16 (compare) → 13 (population, biggest). Each slice ships a PR and
a patch release as it lands ("release as we go"). Reference repos:
`~/src/external/exp-engine-engine` (oracle), `~/src/mn/iso-10303-11`
(normative text), `~/src/mn/iso-10303-detached-docs` (Parts 21/28
sources and fixtures).
