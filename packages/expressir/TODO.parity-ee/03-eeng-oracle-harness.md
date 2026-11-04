# 03 — Build and run eeng as a differential oracle

**Status: NOT STARTED**

## Goal

A working `eengine` binary (SBCL build) we can run over the SMRL corpus
to produce reference outputs (pretty, flat, concatenated, list,
smrl-xml, dot, checks) for differential validation of our ports.

## Steps

1. Install/locate SBCL; build: `sbcl --load sbcl/compile` then
   `sbcl --load sbcl/deliver` (per README.txt) → `eengine`.
2. Reproduce `qualify.sh` flow for a handful of modules from
   `qualify-mod.txt` (their lists == our SRL corpus names).
3. Golden corpus: run all qualify operations for the full
   `resources.lst` + `modules.lst`; commit distilled outputs (not the
   whole tree) under `spec/fixtures/eeng-oracle/` (LFS-sized check
   first).
4. Script `script/eeng-oracle` (or Rake task) exposing one-command
   regeneration; document known eeng bugs/limitations found while
   driving it (feeds 01's coverage flags).

## Acceptance

One command regenerates the golden corpus; at least arm/mim pretty +
flat + concatenated outputs exist for 10 modules and 10 resources.

## Tests

Refreshes the expected outputs consumed by 11's imported specs; the
qual-* drivers are the oracle's entry points.
