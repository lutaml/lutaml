# 00 — RefPath v2: ELF 5006 conformance

Goal: make `Expressir::Mapping::RefPath` a conforming validator for the
EXPRESS mapping language specification (ELF 5006:2025,
`~/src/expresslang/docs/sources/express-mapping/`), so that the WG12
validation of annotated EXPRESS links (TRThurman PDES proposal,
expressir 2.4.20+ capability, AP 242 ed5 DIS December 2026) finds
expressir ready at every reference position.

## Gap matrix (ELF 5006 §8 vs current RefPath)

| §8 requirement | status |
|---|---|
| entity existence, case-insensitive | done |
| `<=` / `=>` subtype/supertype, direct or transitive | done |
| attribute existence for `->` / `<-` (inherited attrs) | done |
| forward/inverse TYPE compatibility (attr type references target; SELECT membership) | v2 |
| navigation continuity (running path context) | v2 |
| constraint: entity in path context; attribute exists; not DERIVED/INVERSE | v2 |
| constraint value typing (STRING/INTEGER/REAL/NUMBER/BOOLEAN/LOGICAL/ENUMERATION/SELECT table) | v2 |
| start entity = ARM entity (relaxable for attribute mappings); end entity = MIM/aimelt | v2 |
| `*>` / `<*` select extension semantics | v2 |
| `!{...}` negation, `<...>` required path, `||...||` marker, `*...*` tree | v2 (tokenize + semantics) |
| collect-all-errors | done |
| structured output (text/JSON/YAML), per-path VALID/INVALID | v2 |
| case-mismatch warnings (optional) | v2 optional |

## Mapping-model gaps (ae-level fields in the wg12-step corpus)

587 module mapping files; keys beyond the current model:

- `rules` — 159 ae entries carry a rules list (a reference position in
  the PDES proposal: "the rules list").
- `alt_map` — 74 ae entries carry an alternative map ("an alternative
  map" reference position).

Both must be modeled with lutaml-model attributes (never hand-rolled
parsing) and their link/reference positions validated like ae/sc.

## Validation semantics (per §8 + §5/§6)

- Running context: the entity a path is "at". `<=`/`=>` move to the
  right-hand entity; `a.attr -> b` requires attr on the current entity
  whose type references b (supertypes and SELECT options count), moves
  to b; `b <- a.attr` same checks, moves to a; `[i]`/`[n]` keep the
  element type as context; a bare name restates or continues the
  context (§6 chaining).
- Constraints `{e ... e.attr = v}`: e equals the current context entity
  (§8: "at or before the constraint location"); attr exists on e and is
  not DERIVED/INVERSE; v typed per the §8 table (STRING single-quoted,
  INTEGER/REAL/NUMBER unquoted, BOOLEAN TRUE/FALSE, LOGICAL +UNKNOWN,
  ENUMERATION item of the attribute's type, SELECT option match).
  `!{...}` inverts the finding.
- Start entity: compatible with the ae `entity` (relaxed for aa-level
  paths). End entity: a MIM-declared entity (cross-check `aimelt`).

## Test oracle

- `spec/expressir/mapping/refpath_spec.rb` — extend with one example
  per §8 rule (firing + clean negative).
- Corpus: all 587 module mapping.yaml files; the suma MappingDrift
  baseline (1541 entries) is the pre-v2 reference; v2 must not add
  errors on paths the corpus proves valid, and must explain every new
  error by an ELF 5006 rule.
