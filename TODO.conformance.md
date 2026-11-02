# TODO.conformance — measured validation conformance (W3C XSD Test Suite)

Goal: conformance is a number, not a feeling. Vendor the W3C XML Schema
test-suite categories, build the harness, publish the pass-rate, grow it.

## Baseline (2026-10-23, 22 cases / 47 checks, full pass)

Corpus: 22 case classes under `spec/conformance/cases/`, modelled on the
W3C XML Schema Test Suite category taxonomy — self-authored because the
canonical 2007 suite distribution is no longer served from w3.org (owner
can vendor a tarball later; provenance README goes with it).

Current (2026-10-25): 23 cases / 49 checks —

| mode | pass-rate |
|---|---|
| engine (Moxml::XSD tier-1, leptris 1.9.380.2) | 39/44 (88.6%, 2 cases unsupported) |
| pipeline (ValidationJob + wired rule engine) | 49/49 (100.0%) |

The pipeline now passes every check in the corpus (locked in by a
runner spec). The engine trails on the four documented below. The
engine's former xsi:type derivation FALSE POSITIVE is fixed in
leptris 1.9.380.2 (moxml#433 closed).

History: 2026-10-20 baseline 20/25 (80.0%) with pipeline == engine
(empty `RuleRegistry`, mismatched rule signatures); 2026-10-21 wiring
baseline 34/39 (87.2%); gap rules 37/39 (94.9%); anyAttribute 40/42
(95.2%); keyref activation via lutaml-model 0.8.121 → 41/42 (97.6%);
lutaml-model 0.8.123 (complexType/extension anyAttribute mappings) +
leptris 1.9.380.2 → 42/42 (100.0%); xs:group expansion in the content
and occurrence walks grew the corpus to 45 checks → 45/45 (100.0%);
abstract-element usage checking → 47/47 (100.0%); wildcard-alternative
choice counting + builtin-memberType union answers via engine-context
wiring (union-simple had regressed to a false positive on main) →
49/49 (100.0%).

Remaining engine-mode gaps (tracked, moxml/leptris-side):

- strict `xs:any` and `xs:anyAttribute` under-detection
  (`invalid-undeclared` instances validate) — documented lax posture
- `xsi:nil` on non-nillable elements accepted
- `namespaces-qualified`: wrong-namespace root accepted (engine
  root-matching skips it; the pipeline's root check catches it)

## Harness

- [x] Conformance corpus under `spec/conformance/cases/` (directory
      convention: schema.xsd + valid-*.xml + invalid-*.xml)
- [x] `Lutaml::Xsd::Conformance::Runner`: discovery, per-mode
      classification, pass-rate report (engine + production pipeline)
- [x] `rake conformance` → prints report and writes
      `tmp/conformance_report.md`
- [x] Deliverable doc: `docs/CONFORMANCE.adoc` (methodology, baseline,
      gap register pointer, how to add cases)
- [ ] Vendor a real W3C XSD TS subset — DEFERRED: upstream distribution
      URLs are dead as of 2026-10-20; the owner supplies the corpus
      tarball and a provenance/license README is added with it
- [ ] Harness run against the rule engine with registries explicitly
      populated — DEFERRED: subsumed by the rule-registry wiring design
      below

## Rule-engine wiring (done 2026-10-21)

- [x] Design note: `docs/superpowers/specs/2026-10-21-rule-engine-wiring-design.md`
- [x] Element-scoped dispatch contract: `ValidationRule#schema_argument`
      (defaults to the resolved declaration; occurrence rule returns the
      content-model particle) and `runs_without_schema?`
- [x] `SchemaDefinitionResolver`: top-level + inline element index with
      namespace matching and named-type resolution
- [x] `RuleRegistry.default(config)`: production rule set, feature-gated;
      shared by `Validator` and the conformance harness
- [x] Rules resolve `type="prefix:Name"` references via the repository
- [x] Substitution groups: content-model and occurrence matching are
      substitution-aware (substitution case now passes in pipeline mode)
- [x] Facet-collection handling fixed (empty arrays were treated as
      present facets; `XmlAttribute` namespace ported to `.uri`)
- [x] Integration specs prove rule findings fire with the engine phase
      disabled (ordering, missing content) and valid instances stay clean

## Rule-engine depth (remaining)

- [x] Identity constraints: `key`, `keyref`, `unique` —
      `IdentityConstraintsRule` (selector/field XPath evaluation,
      duplicate detection, keyref resolution); dangling-keyref detection
      active since lutaml-model 0.8.121 (lutaml-model#990)
- [x] Wildcards: `any` namespace constraints (##any/##other/##local/
      ##targetNamespace/lists) + `processContents` strict declaration
      checking in the content-model walk; `anyAttribute` honors namespace
      constraints and strict checking on every shape — attributeGroup and
      restriction always, complexType-level and extension shapes since
      lutaml-model 0.8.123 maps them (lutaml-model#995); the capability
      probe keeps older models on pre-wildcard behavior
- [x] `xsi:nil` (nillable + empty-content checks) and `xsi:type`
      resolution (unknown-type rejection; content walk follows the
      override); the engine's valid-derived false positive is fixed in
      leptris 1.9.380.2 (moxml#433)
- [x] Particle checking: UPA detection (2026-10-22) —
      `UniqueParticleAttribution` schema-side checker: first-set
      computation over sequence/choice/all with wildcard/element
      overlap, choice-alternative and sequence-junction conflict rules,
      container occurrence folding. Standalone API
      (`findings` → upa_violation findings); zero findings on the
      conformance corpus schemas (no false positives). Depth (2026-10-22):
      xs:group references expand to the referenced declaration
      (cycle-guarded), and element first-sets include substitution-group
      members — head/member junctions report per XSD 1.0 while required
      head/member sequences stay deterministic. Wired into
      `ValidationJob` as an opt-out `validate_upa` phase: schema
      findings surface as warnings and never flip instance validity.
      Also fixed the occurrence rule's choice counting: one instance
      element matching duplicate alternatives counts once, not once
      per alternative
- [ ] XSD 1.1 constructs behind a version flag — DEFERRED: 1.1 strategy
      decision needed (see TODO.som.md)

## Official W3C suite (2026-10-23)

The official suite (w3c/xsdtests, W3C Document License, fetched at a
pinned commit) is measured via `rake conformance:w3c`:

| mode | pass-rate |
|---|---|
| pipeline | 4569/4696 (97.3%) |

(2026-11-02, bundled-stack measurement on main with the escape,
hint-following, pattern-alternative, identity-crash, engine-set,
engine-refresh, IC value-space, IC field-resolution, facade-silence,
regex-semantics, redefine-refresh, gmonth-refresh, digit-vintage,
stgh-refresh, group-ref, attribute-group-redefine and
notation-length rounds; moxml
0.6.1 (gemspec floor `~> 0.6.0` per the owner — the 0.6 line drops
the Opal surface; measured conformance-neutral), lutaml-model
0.8.155, engine leptris 1.9.401.0.) Same-stack comparison: 1.2.43
baseline 3961 (84.3%) → 4039 (86.0%) → 4090 (87.1%) → 4360 (92.8%,
lockfile refresh) → 4411 (93.9%) → 4430 (94.3%) → 4435 (94.4%) →
4436 (94.5%) → 4439 (94.5%) → 4454 (94.9%) → 4495 (95.7%) → 4524
(96.3%) → 4534 (96.6%) → 4540 (96.7%) → 4542 (96.7%) → 4546 (96.8%)
→ 4557 (97.0%) → 4565 (97.2%) → 4569 (97.3%), +608 net over the 1.2.43 baseline. The escapes round (PR #197 — \d→\p{Nd},
\w/\W/\s to their XSD value spaces) collapses Regex 120→69;
same-step pattern facets now behave as alternatives and
whitespace-only text reaches the facets intact (PR #200), Regex
69→59; the REGEX-SEMANTICS round (PR #208) takes \w/\W to their
Appendix F complements (\w = [^\p{P}\p{Z}\p{C}]), adds the \I/\C
complements, carries the Unicode-3.1 legacy Nd set in \d
(U+1369-U+1371, bugzilla 13607) and roots out the unescaped-hyphen
Ruby warning — Regex 59→30. The identity-field xsi:type lookup no
longer crashes when the instance has no override (PR #201) — an
earlier interim 93.9% register had counted that crash as 94 extra
IdentityConstraint failures. The engine compiles file-backed schemas
as a SCHEMA SET (Context#xsd_set, moxml#487 — PR #203), so
cross-document components (substitution members above all) are
visible to the engine; fixed content is checked on type-less and
complex-typed elements and an undeclared root with a resolvable
xsi:type is assessed instead of rejected (isDefault070/077, addB187).
The engine refresh (leptris 1.9.394.0) adds attMa003/004; the
strict-wildcard/attribute admission gap now points at MOXML's facade
SchemaRules re-check (single-document source), filed moxml#510 — the
raw engine admits these documents since leptris#1920, but the facade
finding still fires and even regressed ctE019 on the refresh.
Identity fields compare in their VALUE-SPACE FAMILIES (PR #205) and
the engine's lexical-only duplicate findings for constraints the Ruby
rule evaluated clean are arbitrated out. The IC FIELD-RESOLUTION
round (PR #206) closes 15 more: absent attribute fields now consult
the declaration's fixed/default supply (idF016/017), selector/field
steps resolve in the constraint's namespace governance — unprefixed
element steps match the TARGET namespace (idH020/021), @ns:* wildcard
attribute fields select through the Moxml attribute API because the
engine xpath answers empty for namespace-uri() on attribute nodes
(idL049/idL102), global elements' INLINE complexTypes are form-indexed
(idG027/idH025/030/031), resolve_type(nil) no longer crashes
(idH023), and an out-of-scope (prefixed, other-namespace) field leaves
a KEY row uncontributed instead of incomplete (idG029). Production
hint-following (PR #196, instance_base:) makes multi-document
instances validate fully. The FACADE-SILENCE round: moxml 0.5.177
(its #513) makes the strict re-check silent on composed schemas —
41 cases flip at once (Wildcards 26→3, Schema 23→14, ComplexType
10→4), zero regressions; two shapes still carry findings on composed
schemas (ctE019 attribute re-check, addB116 substitution-member
admission — evidence commented on moxml#510). The dominant remainder
is now the redefine self-extension engine defect (idF025/030/034,
idG019/028, idG024 — leptris#1926, 6 cases), singleton IC corners
(idK012, idZ008/010/011/012/015) and the Regex 59 engine-dialect
corners.

## Suite caveats — what the denominator does and does not contain
(read before "fixing" any remaining failure; 2026-10-31 audit)

- **Denominator**: the pinned suite carries 4755 instance tests; the
  harness measures 4696. The 59 excluded come from testGroups with no
  resolvable schemaTest (schema-less: addB155–addB169, attMd001–011,
  stZ058–066, schA2–A8, ctZ011_a, elemZ017/elemZ033b,
  particlesZ025/026). The pass-rate is over the runnable set, stated
  as x/4696.
- **Contested tests (never chase these)**: 17 instance tests carry TWO
  contradictory `<expected>` entries (Unicode-version dependent; the
  harness takes the FIRST) and 32 more are flagged status="queried" in
  the suite meta. 49 of these live in the excluded schema-less set.
  The remainder that ARE measured (19 today: the reJ class — bugzilla
  4113, where the suite's expectation contradicts the Unicode 3.1
  tables XSD 1.0 cites; gMonth002/004 `--MM--` spellings — leptris
  #1936, FIXED engine-side 1.9.398; reS38/reS17 `\d` vintage —
  leptris #1936, FIXED engine-side 1.9.399; reT51 `\D` vintage —
  leptris #1936 open; addB188, double018_1956, particlesZ001 version
  skew;
  gMonth_pattern001_1274.v — bugzilla 6901 queried 2009 then
  accepted-invalid 2012, but the pattern `--[0-9]{2}--` trivially
  matches the instance `--03--`, so our verdict follows the queried
  reading since the gMonth errata fix) currently FAIL, and our
  verdicts agree with the DISPUTED or Unicode-6 reading. These are
  highlighted, not chased: changing our code to satisfy the first
  expectation would codify a suite mistake.
- **Cap-inert exposure**: the moxml#514 fix (engine cap silent at
  validation) removed a COINCIDENTAL rejection — particlesA013.i was
  passing only because the engine's cap error rejected it; the Ruby
  content rules miss its actual violation (a Particles
  under-detection now in the work queue).
- **Batch crosstalk**: measures run 50 cases per process and suite
  enumeration order is unstable; a handful of cases (the
  NOTATION-length class, idG011/012) pass in isolation and flake in
  batches (a raise in batch context is counted as a failure). A
  single-case probe is the honest verdict for any disputed member;
  per-run ±few-case jitter is crosstalk noise, not code movement.

## Upstream defect inventory (all remaining engine-bound classes)

| Class | Cases | Filed |
|---|---|---|
| Facade strict re-check on composed schemas — remaining shapes (ctE019 attribute re-check, addB116 substitution admission) | ~8 | moxml#510 (+2 follow-up comments) |
| Redefine self-extension drops the extension content model | 0 — FIXED in leptris 1.9.396 | leptris#1926 (closed) |
| Built-in lexical tables reject valid forms (char-reference shapes; gMonth FIXED 1.9.398, \d legacy-Nd FIXED 1.9.399, stG/stH list lexicals FIXED 1.9.400/401) | ~5 | leptris#1936 |
| Automaton size cap surfaces as an instance error instead of engine-inert silence | 0 — FIXED in leptris 1.9.398 | moxml#514 (follow-up to #473) |
| Regex dialect remainder (engine `\d` vintage, `\p{Is...}` blocks, char-reference shapes) | ~30 | engine-side of leptris#1936 |
| Strict wildcard/attribute admission on further compositions | ~5 | moxml#510 thread |
| Ruby-side under-detections (Group 16, DataTypes 7, IC 6, Attribute 5, Additional 4, Particles 4, SimpleType 4, Element 1, Wildcards 1 — minus what the regex round banked) | ~60 | OURS — the remaining Ruby work queue |

Suite history (same-stack where known): 71.8% baseline → 83.5%
(pre-NFA) → 83.6% (NFA + guard, 1.2.41) → 84.3% (#180) → 86.0%
(#181+#182) → 87.1% (#183–#186) → 92.8% (lockfile refresh:
moxml 0.5.170 + lutaml-model 0.8.147) → 93.9% (escape + hint rounds)
→ 94.3% (#200/#201 pattern alternatives and IC crash) → 94.4%
(#203 engine schema-set + fixed-content/root rounds) → 94.5%
(engine refresh leptris 1.9.394.0; IC value-space round PR #205,
4439) → 94.9% (IC field-resolution round PR #206, 4454) → 95.7%
(facade-silence dep refresh, moxml 0.5.177, 4495) → 96.3% (regex
semantics round PR #208, 4524) → 96.6% (redefine refresh, leptris
1.9.396/1.9.397, 4534) → 96.8% (stG/stH refresh, leptris 1.9.401,
4546) → 97.0% (group-ref round PR #217, 4557). Failure
concentration (the work queue, largest first):

- `Regex_w3c` (131) — decomposed by error source (2026-10-25): the
  bulk carry the ENGINE's rejection (leptris XSD-regex dialect lacks
  `\p{Is...}` block escapes and friends, so valid documents are
  false-positived engine-only) — moxml/leptris-side, tracked via the
  moxml issue queue; a pipeline-side minority remains: unescaped `-`
  runs inside classes, exotic `\p` category sets, surrogate-pair
  ranges. `XsdRegex` itself now translates top-level block escapes and
  normalizes block names (hyphen/digit boundaries, upper-run splits,
  Unicode-renamed blocks)
- `DataTypes_w3c` (84) + `SimpleType_w3c` (30) —
  list/union/range facets IMPLEMENTED (2026-10-24); temporal facet
  comparisons IMPLEMENTED (2026-10-25, PR #139): duration orders by
  (months, seconds) per Appendix E, date/time family via DateTime —
  temporal cases 231/270 (85.6%). Remaining corners: typed enumeration
  comparison, gYearMonth edge parsing, duration+pattern combinations
- `IdentityConstraint_w3c` (38) — selector/field depth; multi-field
tuple keys, node-set field violations and absent-field rows handled, cross-element
  scopes
- `Particles_w3c` (24, was 261 at the 76.4% cut) + `Element_w3c` (31)
  + `ComplexType_w3c` (26) — element form defaults, ref particles,
  nested imports, choice occurrence bounds, block= enforcement
  (element- AND type-level block against direct-derivation overrides),
  choice alternatives of any particle kind (choice(sequence(a)) no
  longer counts zero alternatives), global-declaration namespace
  governance (a global element governs qualified use only — an
  unqualified instance child is wildcard territory, not a mismatch),
  ref's minOccurs/maxOccurs governs the expanded container, and a bounded group SEQUENCE
  repeats as a unit), xsi:type
  derivation VALIDITY (an override must be validly derived from the
  declared type — lists/unions derive from anySimpleType, not their
  item types) and schema-level blockDefault (the schema-wide default
  block applies to declarations without an explicit block) are in;
  remaining is composition depth. Rule crashes on xs:all containers
  fixed (typed collect_particles, empty-all semantics, particle_name
  dispatch) — these had been poisoning run-to-run measurements
- `ModelGroups_w3c` (18, was 47) — base-type attributes flow into
  derived types through extension AND restriction (a restriction
  narrows but cannot drop attributes, XSD 1.0 §3.4.2); the mgB/mgF
  rule_execution crashes (xs:annotation leaking into particle lists
  via resolved_element_order) are fixed
- remaining (2026-10-31, bundled-stack complete measurement with the
  escape + hint-following + pattern-alternative + identity-crash +
  engine-set + engine-refresh + IC value-space + IC field-resolution
  + facade-silence + regex-semantics + redefine-refresh rounds,
  4534/4696 = 96.6%):
  Regex (28 — ALL engine-bound: the whole remainder carries a leptris
  verdict; the Ruby \d legacy-Nd fix cannot flip the reS/reT class
  while the engine's own \d keeps the ASCII vintage — leptris#1936),
  Schema (13 — remaining composed-schema shapes on moxml#510:
  addB116-class substitution admission + schA1-class same-root
  multi-document crosstalk; the ctE019 attribute re-check FIXED in
  leptris 1.9.395), DataTypes (17), Particles (18), Group (19),
  AttributeGroup (17), SimpleType (6 — the stG/stH list-lexical
  class FIXED in leptris 1.9.400/1.9.401; remainder is reZ-adjacent),
  Attribute (10), Additional
  (7), IdentityConstraint (6 — idK012/idZ008/010/011/012/015
  singleton corners: cross-namespace keyrefs, IDREF defaults,
  complexContent constraint location — the redefine class FIXED in
  leptris 1.9.396), ComplexType (3), Element (4), Wildcards (3),
  Errata10 (2), ModelGroups (2), Notations (1). Production
  xsi:schemaLocation hint-following SHIPPED (PR #196, instance_base:)
- REDEFINE REFRESH ROUND (2026-10-31): lockfile moxml 0.5.177 →
  0.5.178, lutaml-model 0.8.148 → 0.8.149, leptris 1.9.394.0 →
  1.9.397.0 — the train carried OUR filings: leptris 1.9.395 fixes
  the ctE019 chameleon-include attribute re-check (moxml#510
  straggler), 1.9.396 fixes the xs:redefine dropped bodies
  (leptris#1926 — all six IC cases flip). +10 cases, zero
  regressions. Still open upstream: leptris#1936 (lexical tables —
  gMonth/reZ/stG classes unchanged), moxml#514 (automaton cap as
  error — particlesA/Jb unchanged), moxml#510 stragglers (addB116
  substitution admission).
- GMONTH REFRESH ROUND (2026-10-31): lockfile leptris 1.9.397.0 →
  1.9.398.0, lutaml-model 0.8.149 → 0.8.151 (yeptris 0.6.52 ride;
  moxml STAYS 0.5.178 — the 0.6.0 line is breaking (Opal removal) and
  the gemspec floor `~> 0.5.147` excludes it; a floor bump is an
  OWNER DECISION and has no semantic gain for us). The train carried
  two more of OUR filings: leptris#1936's gMonth leg (both spellings
  validate — gMonth002/004 flip) and moxml#514 (the automaton cap is
  inert at instance validation — particlesA014/A015/Jb003 flip).
  +8 cases, 2 flips documented not chased: gMonth_pattern001_1274.v
  (bugzilla 6901 — see caveats) and particlesA013.i (cap-inert
  exposed a Particles under-detection). Suite 4540/4696 (96.7%).
- DIGIT-VINTAGE ROUND (2026-11-01): lockfile leptris 1.9.398.0 →
  1.9.399.0, lutaml-model 0.8.151 → 0.8.154 (perf) — the train
  carried the \\d leg of leptris#1936 (the Unicode-3.1 legacy Nd set
  joins the engine's digit class; the complement inherits it) —
  reS38/reS17 flip, matching our own legacy-Nd translation from PR
  #208. Regex 30→28; suite 4542/4696 (96.7%). Still open on #1936:
  the reZ char-reference shapes and the stG/stH list-union member
  lexicals; plus the moxml#510 addB116 straggler.
- STGH REFRESH ROUND (2026-11-02): lockfile leptris 1.9.399.0 →
  1.9.401.0 (1.9.400 landed late on rubygems; 1.9.401 adds list
  value-space whitespace collapse before facets) — the train
  carried the stG/stH legs of OUR leptris#1936: inline anonymous
  restriction bases drive list-item length and list lexicals are
  collapsed before pattern/enumeration. All four cases flip
  (stG010/012, stH005/007); SimpleType 10→6; suite 4546/4696
  (96.8%), zero regressions. #1936 remainder: reZ char-reference
  shapes, reT51 \D vintage; plus moxml#510 addB116 straggler.
- GROUP-REF ROUND (2026-11-02, PR #217): +11 Group cases (19→8,
  suite 4557/4696 = 97.0%). TWO Ruby defects: (a) `particle_for_type`
  read sequence/choice/all from extension and restriction bodies but
  NOT `group` — a derivation body that is a bare group reference
  compiled to NO content model and the walk enforced nothing
  (groupG/groupH class); (b) `composite_capacity` decided sum-vs-max
  from the PARTICLE's class — for a Group ref it always took the max
  branch even when the group's declaration is a SEQUENCE whose
  members' capacities must ADD (groupH002: one branch of x1+x2 was
  counted as two choice occurrences). Neighbors verified identical;
  zero regressions. Group remainder: groupB009/010 + groupO004
  (false-reject class), groupH008/J003/006/008/L008 under-detections
  (choice-of-group capacity depth).
- ATTRIBUTE-GROUP-REDEFINE ROUND (2026-11-02, PR #218): +8 net
  (AttributeGroup 17→11, Schema 14→12, Attribute 10→9; suite
  4557→4565 = 97.2%). lutaml-model does NOT chase xs:redefine
  targets — the original document was never parsed, so the
  redefined group's self-ref hook had nothing to hook to and
  expansions truncated at the cycle guard. The resolver now chases
  the redefine target itself (relative to the defining file, via
  the repository's source path), indexes it, keeps the ORIGINAL
  declaration as the hook target, and expands the redefining body
  with the self-ref resolved to that original (attgC007/attgD036).
  Wildcards nested in attributeGroup DECLARATIONS reach types
  through the group's resolution (attgD019). All remaining
  AttributeGroup failures are ENGINE-only strict re-checks on
  composed shapes (the moxml#510 thread).
- NOTATION-LENGTH ROUND (2026-11-02): +4 DataTypes cases (16→12,
  suite 4565→4569 = 97.3%). length/minLength/maxLength are
  FORBIDDEN on QName and NOTATION and every type derived from them
  (XSD 1.0 §4.3.1.2) — a restriction carrying them is IGNORED there,
  and the suite expects the instance to validate. The attribute side
  had no such exemption (the element side already did): the rule now
  walks the restriction's base chain — through NAMED simpleTypes,
  depth-guarded — and skips the length-family check when it reaches
  QName or NOTATION (NOTATION_length001/003, NOTATION_minLength003,
  NOTATION_maxLength001; the direct base is a named type one hop
  above NOTATION, so a direct-base check alone would miss them).
  Zero regressions. DataTypes remainder: anyURI shapes (we-accept),
  duration/dateTime/gMonthDay/gYear corners (engine-bound and
  contested-highlight), gMonth_pattern001 (bugzilla 6901 — do not
  chase), double018 (disputed reading).
- REGEX SEMANTICS ROUND (2026-10-31, PR #208): \w/\W now carry their
  Appendix F complements (\w = [^\p{P}\p{Z}\p{C}], class interiors
  via the exact positive partition L/M/N/S), \I/\C complements added
  (reQ class), and \d carries the Unicode-3.1 legacy Nd set
  (U+1369-U+1371, demoted to No in 4.0.1 — the suite's Unicode-4.0
  expectations keep them, bugzilla 13607; the engine's \d vintage is
  upstream). The class-emitter now hyphen-escapes literals per
  F.1.1 (a '-' after a completed range, at the edges, or before ']')
  — the recurring "character class has '-' without escape" Ruby
  warning is dead at the root. Regex 59 → 30, all engine-bound.
- FACADE-SILENCE ROUND (2026-10-31, dep refresh): lockfile moxml
  0.5.175 → 0.5.177 (its #513 makes the strict re-check silent on
  composed schemas — the moxml#510 fix) + lutaml-model 0.8.147 →
  0.8.148 (+ yeptris 0.6.51 ride; leptris stays 1.9.394.0 — 1.9.395
  is a UTF-8 performance release, not yet resolving in the lockfile).
  +41 cases at once, zero regressions: Wildcards 26→3, Schema 23→14,
  ComplexType 10→4, Element 5→4. Upstream follow-ups posted: moxml
  #510 comment (ctE019 attribute re-check + addB116 substitution
  admission still fire on composed schemas), leptris#1926 comment
  (idG024 joins the redefine tally, 6 cases).
- IC VALUE-SPACE ROUND (2026-10-30, PR #205): identity field keys are
  tagged with their value-space FAMILY — decimal + integer derivatives
  share one space (idL090 holds), float/double and boolean are DISJOINT
  primitives, so identical lexicals in disjoint spaces are distinct
  identities (idF012 boolean-1 vs decimal-1, idF013 float vs decimal,
  idF014 float vs unsignedByte; the instance xsi:type anchors the
  space even when it names a built-in). The ENGINE duplicate findings
  for constraints the Ruby rule evaluated clean are arbitrated out
  after the identity pass (the engine unique check is lexical-only);
  blast-radius scan: exactly ONE engine-decided IC case exists
  (idG006) and its finding is missing-field-shaped, not
  duplicate-shaped, so the arbitration touches nothing. IC 30 → 27.
- ENGINE REFRESH ROUND (2026-10-30): lockfile leptris 1.9.390.3 →
  1.9.394.0 (engine train: xs:override base chase leptris#1913,
  strict-wildcard admission across sets leptris#1920, binding floor
  1.9.386). attMa003/004 flip valid; ctE019 REGRESSED on the refresh —
  triaged as the facade SchemaRules single-document-source blind spot
  (moxml#510, evidence comment posted), not a Ruby-side defect. The
  wildcard-admission class did NOT flip with the engine fix because
  the facade re-check (lib/moxml/xsd/schema_rules.rb) still reads one
  schema source — moxml#510 tracks the fix shape (set-wide declaration
  index, or defer to the engine's admission).
- ENGINE SET ROUND (2026-10-30, PR #203): EngineContext compiles all
  file-backed schemas as ONE schema set via Context#xsd_set (moxml
  #487; lockfile rides 0.5.175) when every document compiled cleanly
  per-file — cross-document components (substitution members, addB132)
  become engine-visible. ENGINE-STABILITY LESSON: a failed native
  compile POISONS the engine's state — repeated failures abort a later
  validation with SIGABRT (elemO001 after 3+ failed dtZ compiles);
  failed set attempts per case must never stack, so the set is only
  attempted when per-file compiles are all clean, and failed handles
  are released (release alone is NOT enough — the poison survives it).
  Broken schemas keep exactly the per-file inertness of the old path.
  Also: fixed content checked on TYPE-LESS (implicit anyType) and
  COMPLEX-TYPED elements (isDefault070/077 short-circuited before the
  check), and an undeclared root with a RESOLVABLE xsi:type is
  assessed against that type instead of rejected (addB187). Filing:
  leptris#1920 (wildcard admission across set documents).
- PATTERN ROUND (2026-10-30, PR #200): same-step pattern facets are
  ALTERNATIVES (XSD Part 2 §4.3.4.4) in both the element and attribute
  rules — p16/p17/p20; `XmlElement#text_content` now returns raw
  character data, with emptiness a stripped check at the consumers, so
  a lone newline matches `[\n]` (reG11/reG13). Regex 69→59, +10 net,
  no family regressions (before/after list diff).
- IC CRASH ROUND (2026-10-30, PR #201): the xsi:type local-name
  lookup in `field_declared_type` ran `match?` on the nil result of
  splitting an empty string, so every identity-constraints pass over a
  document whose field nodes carry no xsi:type aborted with
  rule_execution_error — 94 IdentityConstraint cases (every idF/idG
  element-field case). Guarded; IC back to 198/228 (30 failures). The
  interim 93.9% register predates the crash scan, so its IC=30 number
  described code before this regression, not after it.
- IC ROUND (2026-10-28): (a) prefixed WILDCARD selector steps
  (`.//myNS:*`) now translate to namespace-uri() tests — they slipped
  through the earlier adaptation untouched and the key never built
  (idL085); (b) the zero-occurrence guards crashed on
  maxOccurs="unbounded" (parse yields a Symbol, `.zero?` raised) —
  every schema with an unbounded container turned the occurrence rule
  into a rule_execution_error, a live false-reject class since the
  guards landed; (c) numeric-typed key fields canonicalize to actual
  NUMBERS — decimal 1 == integer 1 stays unified, and neither equals
  the string "1" (cross-space distinctness, idL090); both keyref
  sides canonicalize identically; (d) for xs:KEY a selected node
  whose fields do not all evaluate is an error
  (key_field_absent_violation, xmllint-arbitrated), uniques/keyrefs
  keep the skip.
- ATTRIBUTE TYPE VALIDATION (2026-10-28): validate_attribute_type was
  a stub — attribute values were never checked. Now: built-in lexical
  via the engine table (lax without an engine), restriction facets
  (enumeration, pattern, length family, ranges through the shared
  ValueSpace keys — numeric/duration/temporal), list items, unions
  (all-members-fail). +3 net suite (Additional 44→41). Remaining
  Attribute classes: attributeGroup-in-restriction shapes (attLb —
  aga1-style refs unreached), use=/default under-detections (attMb),
  engine attribute-lexical false rejections (attO — moxml queue)
