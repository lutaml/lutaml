# 04 — Compiled-set + lazy path as the suma default build

## Goal
suma builds parse the SMRL once into an EXSCS1 artifact and all document
renders hydrate per schema from it (warm start 7.8s vs 12s cold), instead
of eager-parsing on every build.

## Steps
- locate the suma/rake build entry that calls Parser.from_files
- switch to `Parser.from_files(files, compiled_set:)` then
  `LazyRepository.new(set)`
- keep an escape hatch (env) for debugging with eager parse

## Acceptance
- a suma build log showing one artifact build + per-page hydration
- rendered output byte-identical to the eager path
