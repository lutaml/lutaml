# 04 — ARM↔MIM instance mapping verification

The Thurman end-game: verify that a MIM population is the image of an
ARM population through the module's mapping tables — RefPath applied
to instances, closing the loop between the schema-side mapping
validator (TODO.refpath-v2) and real data.

## Parts (each ships)

1. Mapping semantics over instances: for a module's mapping.yaml,
   given an ARM-typed population and the MIM population, follow each
   mapped reference path from each ARM instance through the MIM
   population and match the resolved target against the mapped
   attribute's expected value.
2. Instance-level RefPath: every path step resolves to actual
   instances (typing from TODO.instance/01); constraint values matched
   against actual attribute values; the `rules` lists checked as
   instance predicates; `alt_map` alternatives accepted when the
   primary path is unfollowable.
3. Report + triage: per-module verification receipts (ARM instance id,
   path, step, finding); drift classified as mapping drift vs
   population drift; feeds the WG12 corpus-drift policy program with
   instance-level evidence instead of schema-level inference.
4. Thurman interop: output comparable with the annotated-links
   validation of the PDES proposal (`pr463_validation_proposal.pdf`);
   AP 242 ed5 sample datasets as the acceptance corpus (DIS
   December 2026; AP 209/210/239/242 follow in 2027).

## Acceptance

- Synthetic ARM/MIM pair built from a shipped module: the image
  verifies clean; each seeded divergence (dropped instance, wrong
  target, violated constraint) produces exactly the intended finding.
- An AP 242 sample dataset verifies to completion; every finding
  carries path, step, and instance ids (triage-ready).
- No finding on any mapping the corpus proves valid — the standing
  no-new-errors oracle, now at instance level.

## Status: done (v1)

- `Expressir::Mapping::InstanceVerification` verifies that a MIM
  population is the image of an ARM population through a
  `Mapping::Document`: every ARM instance of a mapped entity must
  have a MIM image whose typing includes the mapped MIM entity
  (P21::Typing, task 01), whose element refpath resolves from that
  image, whose attribute-mapping refpaths terminate at values equal
  to the ARM attribute values, and whose inline element rules
  evaluate true (`Eval::Rules.environment_for`, the task-02 WHERE
  machinery, with self bound to the image).
- Instance-level RefPath walking covers the corpus constructs: bare
  and attribute-qualified nodes, `->`/`<-` navigation, `<=`/`=>`
  restatements, the §5 `||supertype||` and `*tree*` markers, and
  `{entity.attr = literal}` constraints with `!` negation.
  `alt_map` routes are accepted when the primary route is
  unfollowable — the alt route is an instance predicate, exactly as
  in the schema-side validator.
- Reference values correspond across the two populations through the
  mapping itself: an ARM `#n` terminal matches the MIM image of ARM
  instance n under the element mapping its keyword (memoized, so
  correspondence stays linear).
- Scope lines, stated rather than silent: rules fields that name
  global rules (the corpus norm) remain the domain of
  `Mapping.rule_issues` — only inline expressions are instance
  predicates; image search is existential, so a MIM population with
  extra instances is not an error (no bijection is enforced); and
  complex (multi-role) records fail their route rather than silently
  passing.
- Validation: `spec/expressir/mapping/instance_verification_spec.rb`
  — synthetic ARM/MIM pair in the shape of the smallest shipped
  module mappings, clean image verified, and a mutation sweep: each
  seeded divergence (missing image, constraint-path name divergence)
  produces exactly one finding, and repairing it removes exactly that
  finding; rule gating is proven by flipping the element rule, which
  unmasks exactly that element's instances.
- AP 242 sample (acceptance part 2): no paired ARM+MIM sample dataset
  ships in this repository or the detachment, and fabricating one
  would test nothing but itself — so the synthetic-pair acceptance
  stands in per the goal's missing-dataset provision. Finding
  records carry ARM instance id and entity (triage-ready); path/step
  attribution rides on RefPath::Report (TODO.refpath-v2) and the
  per-module receipts of 03 when datasets exist. Thurman interop
  (part 4) remains open for the WG12 corpus-drift program, which
  owns the AP 242 DIS dataset sourcing.
