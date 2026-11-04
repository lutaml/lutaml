# 06-change-classification — Semantic change classification

 SchemaCompare deltas classified breaking vs additive through the subtype graph and the ISO 10303-11 Annex K deprecation policy. Acceptance: a seeded breaking change (supertype attribute removal) classifies breaking; an additive one (new subtype) classifies additive; classification rides the report.

## Status: done

- `Expressir::Express::ChangeClassification`
  (`lib/expressir/express/change_classification.rb`): classifies
  SchemaCompare deltas through the base schema's subtype graph —
  `:added` is additive; removals and signature changes are breaking,
  carrying the affected direct subtypes of the owning entity.
- ISO 10303-11 Annex K deprecation policy: paths the schema edition
  already announced for removal are flagged `deprecated` on the
  verdict (the removal stays classified breaking — the flag carries
  the policy).
- Rides the report: the `schema.changes` emission's
  `modified.object` elements carry `classif="breaking|additive"`
  (`Commands::Compare` classifies every delta before emission);
  readers ignoring unknown attributes are unaffected — registered as
  divergence D-05.
- Specs: `spec/expressir/express/change_classification_spec.rb`
  (acceptance cases: supertype attribute removal → breaking with
  affected subtypes; new subtype → additive; declaration removal;
  signature change; deprecation flag; unclassified-until-applied);
  report emission pinned in
  `spec/expressir/commands/compare_spec.rb`.
