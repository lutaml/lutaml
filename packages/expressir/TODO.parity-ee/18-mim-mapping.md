# 18 — EXPRESS MIM mapping parser (expressir#88)

## Goal

Parse and validate MIM "reference path" mappings — the application ↔
interpretation mapping every STEP module carries — into a typed model,
with the mapping paths validated against the ARM/MIM schemas.

## Sources

- This checkout's canonical form: `schemas/modules/*/mapping.yaml` —
  structured ae/aimelt/aa records whose values use the
  `<<express:SCHEMA.ITEM,ITEM>>` link markup (the same markup
  `Suma::LinkValidation` validates today). Generated upstream from
  module.xml.
- Upstream SMRL module.xml: `mapping`/`ae`/`aimelt` elements with
  `reference_path` bodies — the ISO 10303-1x mapping methodology
  grammar: entity chains `A -> B -> C`, qualifiers `[attr => val]`,
  `=>` derived references, `->>` subtype traversal, `<>` select
  member. Port the grammar from the Part 1x mapping annex text
  (detached docs) + existing module corpus as the oracle.
- eeng has no counterpart — this is an expressir-first capability.

## Design

1. `Expressir::Model::Mapping` — MappingDocument →
   ApplicationElements (entity, aimelt, attributes) and
   ReferencePath nodes (path-expression AST: steps, qualifiers,
   subtype traversals).
2. `mapping.yaml` reader (lutaml-model typed) — yaml → MappingDocument.
3. Reference-path expression parser — parsanol grammar over the path
   syntax; AST reuses Model::References where shapes coincide.
4. Validation: every path resolves against the resolved ARM+MIM
   repository (rides SchemaIndex / ItemGraph); unknown step = error
   note (Checker id `check-mapping-path`).
5. CLI: `expressir mapping validate DIR|FILE` over module dirs.

## Acceptance

- All module mapping.yaml files in the SMRL parse; path validation
  reports zero unknown steps (or a classified, explained residue).
- Round-trip: MappingDocument → yaml byte-stable.

## Test cases

- module corpus (603 modules); hand fixtures for each path grammar
  production; invalid-path fixtures.
