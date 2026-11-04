# 04 — Concatenated EXPRESS artifact (expressir#247)

**Status: SHIPPED (2026-09-21)** — `Expressir::Express::Concatenator`
(closure + writer + one-call `call`), eeng-semantics ordering and
section format (alphabetical, `-- NAME (file)` separators, verbatim
source copies); specs: synthetic closure/round-trip + ENV-gated eeng
differential (byte-identical sections vs `--concat_schema` for
description_assignment ARM). Golden oracle outputs committed for ARM
and MIM. During this stage the small-input USE FROM parse bug was
found and reported as expressir#373.

## Goal

`expressir` command producing a **concatenated** `.exp`: the root
schema followed by every USE FROM / REFERENCE FROM dependency
(non-circular closure), each as plain EXPRESS (no remarks), with an
SRL publication header listing the schemas. This is the SHTOLO
precursor and a WG12 qualification/provenance artifact.

## Reference

- eeng mode `(:arm/:mim :concatenated)` — `kernel/engine.lisp` mode
  table, `plugins/p11/top-level.lisp` (concatenated handling +
  `arm_concatenated.exp` outputs in qualify.sh), SMRL index hook at
  wo-smrl-xml.
- Our graph: dependency closure via `Repository#reference_index`
  (interface edges) + topological, cycle-safe ordering already
  demonstrated by the item-graph work.

## Design sketch

- `Expressir::Express::Concatenator.call(repository, root_schema)` →
  model-level ordered schema list (respect eeng's ordering rules —
  read their code in 02 first).
- Writer: plain schemas (no remarks) + banner comment enumerating
  sources (schema name, file, copyright per SRL conventions).
- CLI: `expressir concatenate <manifest/root.exp> -o out.exp`.

## Acceptance

- Output parses back with our parser (self round-trip).
- Diff vs eeng `arm_concatenated.exp`/`mim_concatenated.exp` for the
  03 golden set: schema set + order identical (formatting differences
  documented, ideally zero after 08).
