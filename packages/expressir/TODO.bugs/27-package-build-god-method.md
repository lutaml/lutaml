# 27 — Package#build is a 195-line god method

**Priority:** P1 (god method)

## Problem

`lib/expressir/commands/package.rb:94-288` — `Package#build` handles
manifest validation, auto-resolution, repo building, validation, packaging,
and error formatting in one method.

## Fix

Extract `build_from_manifest`, `build_from_auto_resolution`,
`run_validation` as private methods.

## Acceptance

- No method exceeds 40 lines.
- All package specs pass.
