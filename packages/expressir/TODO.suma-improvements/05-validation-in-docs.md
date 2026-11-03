# 05 — Corpus validation surfaced in suma builds

## Goal
The expressir validation layers (mapping_validate incl. refpath
resolution — which found 2 genuine corpus drifts in a 60-module sweep)
run as part of suma builds, reporting per-module drift in the build log
(and optionally in published output).

## Steps
- wire `expressir mapping_validate` over each module's mapping.yaml in
  the suma build loop
- aggregate a drift report artifact; non-zero exit only on NEW drift vs
  a committed baseline file

## Acceptance
- baseline for the 2 known drifts; a build with a synthetic new drift
  fails with the module/location in the message
