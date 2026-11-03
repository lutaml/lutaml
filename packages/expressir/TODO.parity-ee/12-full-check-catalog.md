# 12 — Full check-p11 catalog port (eeng `kernel/check.lisp`)

## Goal

Bring `Expressir::Express::Checker` from the current documented subset
to the full eeng check-p11 catalog: every note eeng 5.1.0 emits over
the SRL/SMRL corpora, with note ids and severities aligned so oracle
differentials stay cross-referenceable.

## Current subset (shipped)

check-schema-interface-redundant, check-schema-iface-resource-duplicate,
check-subtype-ref, check-subtype-cycle (path-tracked DFS),
check-duplicate-declaration, check-where-name-pattern,
check-unique-name-pattern, check-unresolved-ref,
check-select-extended-type, check-enumeration-extended-type,
check-self-schema-reference (#125), parse-failure → nonzero exit.

## Sources

- `~/src/external/exp-engine-engine/kernel/check.lisp` (835 lines,
  `check-p11` generic + per-node-type methods) and
  `kernel/check-notes.lisp` (note catalog).
- ISO 10303-11:2004 clause text — `~/src/mn/iso-10303-11/sources/sections/`
  (each ported check cites its clause).
- Existing plan: `07-semantic-checks-port.md`; current impl
  `lib/expressir/express/checker.rb`.

## Design

1. **Catalog extraction**: enumerate every `post-message` site in
   check.lisp/check-notes.lisp → (note-id, severity, node type,
   message shape). Commit as `spec/fixtures/eeng/check-catalog.md`
   with our coverage column; CI gate diffs the catalog against the
   oracle so new eeng notes surface.
2. **Port order** (by eeng's own walk): schema-level (interfaces,
   constants) → entity (supertype/subtype-of, attributes, derives,
   inverses, uniques, wheres) → type (select/enumeration/aggregate
   bounds) → function/procedure/rule bodies (expression typing lite:
   arity/name resolution of called functions, built-ins from BUILTINS,
   variable scoping via ScopeResolver) → attribute-level
   redeclaration consistency (redispatches, `SELF\` qualifiers).
3. **Differential gate**: run eeng `--validate` and our `validate
   check` over the SRL corpus + module arm/mim set; every corpus file
   must produce the SAME note-id multiset (message text may differ).
   Land as `checker_eeng_full_catalog_differential_spec`
   (production_scale-tagged for the big corpus; small fixtures in the
   default suite).
4. **Severity mapping** table: eeng `:error/:warning` → ours verbatim.

## Acceptance

- Catalog file lists 100% of eeng note ids with status columns.
- SRL differential: zero unexplained note-id mismatches.
- `validate check` docs updated (README table).

## Test cases

- eeng `docs/issues/` corpus inputs; qualify loops
  (`scripts/qual-*.sh`) over resources.lst/modules.lst.
- Per-clause unit fixtures citing ISO 10303-11 clause numbers.

## Release checkpoint

PR + expressir patch release once the entity/type/schema tiers land
(expression-tier notes may follow in a second PR — keep the catalog
honest about which tier each note belongs to).
