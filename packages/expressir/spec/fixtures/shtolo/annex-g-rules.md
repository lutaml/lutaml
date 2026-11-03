# ISO 10303-11 Annex G — conversion rules, extracted

Source: `~/src/mn/iso-10303-11/sources/sections/ag-single-schema.adoc`
(2004 edition, normative). Every rule carries an id, a stage, a
statement, the fixture(s) that exercise it, and eeng coverage
(verified by source grep + oracle runs 2026-09-21; **eeng does not
implement full Annex G** — treat it as a partial oracle only).

Coverage legend: ✅ implemented · ◐ partial · ✖ absent (grep-verified)
· ? unverified.

## G.0 Fundamentals

- **G.0.1** Two stages: (1) multi-schema → intermediate single
  `artifact` schema (still 2003-edition); (2) `artifact` → `longform`
  (1994 constructs only). The intermediate has no validity outside
  the process.
- **G.0.2** Input = the set of root/primary schemas of the schema
  graphs; the input **shall be referentially complete** (no
  unidentified references).
- **G.0.3** Stage-1 transformations: prune select items not
  interfaced; prune subtype_constraints and rules to the pruned
  subtype graph; rewrite schema names in qualified attribute refs to
  the longform name; convert interface knowledge (visibility /
  instantiability) into rules.
- **G.0.4** Accepted semantic losses: schema-of-origin knowledge;
  untagged remarks may be discarded; identifier case may change.
- **G.0.5** Stage-2 actions: resolve extensible selects/enums; remove
  subtype_constraints (supertype/abstract → SUPERTYPE statements,
  total_over → rules); abstract entity/generic entity → abstract
  supertype constraints; RENAMED → DERIVE; **error on empty select**.

## G.NM Name munging

- **G.NM.1** Name clash ⇒ prepend `<schema>_dot_` to every clashing
  declaration, update all occurrences. (Annex example: `thing` in
  `scha`+`schb` ⇒ `scha_dot_thing`, `schb_dot_thing`.)
  Fixture: two schemas each declaring `dog` (farming/pet_shows
  example). eeng: ✖ (no `_dot_` in sources).
- **G.NM.2** Fully-qualified names inside strings (`'SCHA.WHATSIT'`)
  ⇒ schema part rewritten to the target schema name.
  Fixture: `IF 'THIS_SCHEMA.AN_ENTITY' IN TYPEOF(x)`. eeng: ?

## G.1 Stage 1 — multi-schema → artifact

- **G.1.1** Primary population: create `artifact`; copy all
  declarations + tagged remarks from root/primary schemas; no
  schema_version_id; resolve clashes (G.NM.1); rewrite strings
  (G.NM.2). eeng: ✖ (no `artifact` in sources).
- **G.1.2** Interface dedup: drop duplicate USE/REFERENCE items; item
  in both ⇒ delete from REFERENCE (USE wins).
- **G.1.3** USE items: copy into artifact (with tagged remarks) as if
  declared locally; **renamed items copied under their ORIGINAL
  name**, references updated (`alfred AS alf` ⇒ `ENTITY alfred`,
  refs to `alf` become `alfred`). Fixture: sch/second example.
- **G.1.4** Delete all USE specifications from artifact.
- **G.1.5** Secondary population (REFERENCE items): copy those needed
  for referential completeness; skip the rest (preserves REFERENCE
  semantics). Fixture: export/import example.
- **G.1.6** Referenced **entities** keep dependent-instantiability:
  generate `RULE validate_dependently_instantiable_entity_data_types
  FOR (...)` + `FUNCTION dependently_instantiated(...)` (full text in
  the annex; USEDIN/TYPEOF/recursion with chain anti-loop). Update
  FOR-clause and the `all_instances` union for every such entity;
  include entities they need for completeness that appear nowhere
  else as independently instantiable; when input primary schemas are
  themselves longforms, merge their existing rule's FOR contents.
  eeng: ✖ (`dependently_instantiated` absent from sources).
- **G.1.7** Copy **implicitly interfaced** declarations needed for
  completeness, recursively (colour/stop_light, s1-s4
  ENUMERATION BASED_ON examples). Limits (see G.1.9): supertype pulls
  no subtypes, select pulls no items, rule pulls no parameters.
- **G.1.8** Tagged remarks travel with their declarations; untagged
  remarks may be dropped (G.0.4).
- **G.1.9 Prune pass**:
  - supertype constraint expressions pruned per **Annex C**
    reductions (`ONEOF(A,<>) ⇒ ONEOF(A)`, `ONEOF(A) ⇒ A`, vacuous ⇒
    delete constraint; example reduces `ONEOF(m,f) AND ONEOF(c,a)` →
    `m AND a`); eeng: ◐ (total_over/compute-inheritance present).
  - rule with any invisible parameter ⇒ delete (with tagged remarks).
  - function/procedure not called by any artifact declaration ⇒
    delete.
  - select list items not visible ⇒ delete item (list may become
    empty; empty list disappears from the representation — s1/s2/s3
    example); stage 2 turns a surviving empty select into an error.
  - delete all REFERENCE specifications.
- **G.1.10** Optional embedded provenance remark — if any schema name
  is kept, ALL are: `(* Original 2003 schemas:` then
  `schema = <id> [schema_version_id = '<v>'];` lines, order
  insignificant.

## G.2 Stage 2 — artifact → 1994 longform

- **G.2.1** Initialisation: create `longform`; copy everything;
  rewrite qualified strings.
- **G.2.2 Extensible trees (general)**: every extensible/extending
  type ⇒ non-extensible type of the same name whose items = the full
  domain in longform scope; extending types become defined types over
  their base; exclusions via local WHERE rules (one per excluded
  item); unreferenced copies produced by the procedure ⇒ delete.
- **G.2.3 Extensible enumeration**: base becomes
  `ENUMERATION OF (<all items>)`; extension becomes
  `TYPE x = base;` with `wr : SELF <> <item>;` per exclusion
  (three-type example: domain3 gets `SELF <> pending`, `SELF <>
  rework`). CAVEAT: 1994 enumerations are ORDERED; 2003 are not.
  eeng: ◐ (EXTENSIBLE/BASED_ON handled in 8 files).
- **G.2.4 Extensible select**: same pattern; exclusions are
  `wr : NOT ('LONGFORM.<ITEM>' IN TYPEOF(SELF));` (attachment_method
  example). **Empty select after conversion is an error** (the
  `problem` schema example is impossible to convert). eeng: ◐
  (`select-leaves.lisp`).
- **G.2.5 Subtype constraints removed**:
  - **total_over** ⇒ global `RULE total_over_<constraint_name> FOR
    (<supertype>);` whose WHERE enforces membership via
    `SIZEOF(QUERY(... TYPEOF ...)) = 0` (full example in annex);
    tagged remarks reassigned to the rule (repeated per rule).
  - instantiation constraints (AND/ANDOR/ONEOF) ⇒ parenthesized,
    attached as `SUPERTYPE OF (...)` on the entity; multiple
    constraints combine via ANDOR (`ENTITY p SUPERTYPE OF (m AND a)`).
  - `ABSTRACT SUPERTYPE` moves onto the entity declaration.
  eeng: ◐ (total_over in 4 files).
- **G.2.6 Abstract entity & generalized types**: `ENTITY x ABSTRACT;`
  ⇒ `ABSTRACT SUPERTYPE`; `GENERIC_ENTITY` params/locals ⇒
  `GENERIC` (algorithm may need adaptation); generalized attributes:
  (a) all subtypes redeclare to the same type ⇒ migrate it to the
  supertype attribute; else (b) synthesize
  `<entity>_<attribute>_select` SELECT of all redeclared types,
  naming unnamed aggregates as `<agg>_of_<basetype>` (possibly
  recursively), keep subtype redeclarations (nary_relationship
  example).
- **G.2.7 RENAMED in redeclaration**: rename-only redeclaration ⇒
  removed; otherwise keep the typed redeclaration, drop `RENAMED
  <new>`, and add `DERIVE <new> : <type> :=
  SELF\<supertype>.<old>;` (person_in_structure example). NOTE:
  failures if the new name is assigned to — manual fix-up documented.

## eeng partial-coverage summary (2026-09-21 greps)

`artifact` ✖, `_dot_` ✖, `dependently_instantiated` ✖ ⇒ eeng's
`:flat`/`:longform` modes are a simpler merge than Annex G. `total_over`
◐ (4 files), `EXTENSIBLE`/`BASED_ON` ◐ (8 files), longform mode ◐
(6 files). **Consequence: where eeng and Annex G disagree, the annex
wins; eeng output is a comparison input, not the contract** (matches
TODO.parity-ee/05).

## Audited status (2026-10, feat/eengine-tasks)

Live examples in `spec/expressir/express/shtolo_annex_g_rule_audit_spec.rb`:

| rule | audited | expressir |
|------|---------|-----------|
| G.NM.1 | yes (farming/pet_shows dog clash: every clashing declaration munged, occurrences rewritten) | pass |
| G.NM.2 | yes (TYPEOF string rewrite) | pass |
| G.1.1 | yes (artifact population asserted by every worked example) | pass |
| G.1.2 | yes (USE wins over REFERENCE twin) | pass |
| G.1.3 | yes (alfred AS alf: copies under ORIGINAL name, refs rewritten) | pass |
| G.1.4 | yes (no USE specification survives) | pass |
| G.1.5 | yes (completeness-only secondary population) | pass |
| G.1.6 | yes (REFERENCE entities ⇒ annex rule + dependently_instantiated pair) | pass |
| G.1.7 | yes (BASED_ON chain pulls the implicit BASE enumeration; subtyped enumerations carried for completeness) | pass |
| G.1.8 | yes (tagged remarks travel on interfaced entities) | pass |
| G.1.9 | yes (uncalled functions pruned; select/empty-select via G.2.3/G.2.4) | pass |
| G.1.10 | yes (implemented: `add_provenance_remark!`, all-or-none names) | pass |
| G.2.1 | yes (longform initialisation asserted by every worked example) | pass |
| G.2.2 | yes (BASED_ON select chain folds to the full domain) | pass |
| G.2.3 | yes (extensible enumeration fold + exclusions) | pass |
| G.2.4 | yes (extensible select fold) | pass |
| G.2.5 | yes (total_over ⇒ global rule; ONEOF ⇒ SUPERTYPE OF; ABSTRACT moves) | pass |
| G.2.6 | yes (ABSTRACT SUPERTYPE kept) | pass |

Every Annex G rule now has a live worked example.
