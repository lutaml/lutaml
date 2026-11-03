# TODO.instance — the instance-data program (vision)

Expressir made the schema side of ISO 10303 machine-checkable and
citable (TODO.sota). The other half of the standard is instance data:
STEP populations exchanged as Part 21 files and validated against
schema editions. This program makes Expressir the open engine for
instance-data conformance — type every instance, check every value,
evaluate every rule, at population scale, with attestable receipts
binding a dataset to a schema-library release. Same yardstick as
TODO.sota: every validator claim backed by a clause, a worked example,
and a corpus run.

## Where we already are

- `Expressir::P21`: reader (header, simple/complex instances, nested
  aggregates, typed parameters, short names) and the structural
  validator (clause-12 slot mapping, arity, reference integrity,
  enumeration membership, derived-slot discipline).
- `Expressir::Eval` (TODO.sota/02): full ISO 10303-11 ch.12/ch.13
  evaluator; `Rules.check` evaluates entity WHERE rules over Part 21
  populations with SELF and mapped-attribute bindings.
- JSON bridge: JSON Schema export of schemas (TODO.sota/05) and the
  population→JSON serialization built for the Annex H consumer test.
- ISO 10303-21 conformance fixtures under `spec/fixtures/p21/conformance/`
  (annexes E/I/J currently loud-fail by design — the ladder gap).
- Schema side for scale: compiled-set artifacts, LazyRepository,
  subtype/interface graphs computed over the 1,307-schema SMRL set;
  ItemGraph is the noted remaining class.

## Execution order and status

| n | task | tier | status |
|---|------|------|--------|
| 01 | instance typing + value/type conformance | semantics | done (P21::Typing entity closure incl. complex/ONEOF 9.2.5/9.2.5.2; slot value/type conformance :check_p21_* per ch.8/9.2.1/9.2.2.2; SELECT membership 8.4.2; Annex H clean; mutation sweeps) |
| 02 | population-scale rule engine (UNIQUE, global rules) | execution | done (Eval::Population: typed entity bucketing, UNIQUE 9.2.2.1 across subtypes, global RULE 9.4 with FOR aggregates; 10^5-instance benchmark 29.4s deterministic) |
| 03 | P21 ladder completion + population management + receipts | platform | done (named DATA sections + ANCHOR/REFERENCE/constants + signature lines; DatasetManifest + `population validate` + `population diff`; byte-stable JSON receipts; P28 deferred — needs the -28 derived-XML-schema program) |
| 04 | ARM↔MIM instance mapping verification | semantics | done (Mapping::InstanceVerification: image-of search over P21::Typing + RefPath instance walks incl. constraints/alt_map/rules; cross-population reference correspondence; mutation-swept) |

Dependency shape: 02 consumes 01's typing (rule applicability and
SELECT scoping are typing queries). 03 is independent of 02 (files,
manifests, diffs, receipts compose whatever validator exists). 04
consumes 01 (MIM instance typing) and the RefPath mapping model
(TODO.refpath-v2, landed).

## Sources

- ISO 10303-11 text: `~/src/mn/iso-10303-11/sources/sections/`
  (ch.8 data types incl. domain WHERE, 9.2 attributes/UNIQUE,
  9.4 global rules, ch.12/13 already evaluated).
- ISO 10303-21: `~/src/mn/iso-10303-detached-docs/sources/iso-10303-21/`
  (annex E named data sections, annex I ANCHOR/REFERENCE, annex J
  constants; annex H worked example already a fixture).
- stepmod schema slices: `~/src/mn/iso-10303-stepmod/data/` (fast
  <250 KB slice; full 1,307-schema set) and
  `~/src/mn/iso-10303/schemas/modules/` (mapping.yaml corpus).
- ELF 5006 mapping specification:
  `~/src/expresslang/docs/sources/express-mapping/`.
- eengine oracle: `~/bin/eengine` — `-MODE RESOURCE -STEPMOD`; note
  `--validate` aborts on bare p11, so differentials use mutation
  sweeps and, where schemas load, eeng compare.
- Instance corpora: AP 242 / Thurman validation-proposal datasets
  (`pr463_validation_proposal.pdf`), plus round-trip corpora from the
  JSON bridge and the Annex H fixture.

## Environment notes

- Run suites in chunks (full single-process runs OOM on this box);
  gate corpus tiers behind env flags as in TODO.sota/03.
- Standing rules carry over: semantics in Ruby (expressir-rs native
  only on measured, benchmarked need); lutaml-model mappings only;
  Array()-guard nil collections; real model instances, never doubles;
  spec paths match describe subjects; rubocop -A every touched file;
  one PR per task, branch off origin/main, rebase-merge when green.
