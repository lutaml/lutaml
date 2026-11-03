# Design: complete Moxml migration, run on leptris, integrate `Moxml::XSD` engine validation

- Date: 2026-10-20
- Status: approved (design discussion 2026-10-18..20)
- Scope: lutaml-xsd 1.1.x

## 1. Context

lutaml-xsd is ~95% on Moxml already: `validation/*`, `definition_extractor.rb`,
and most of `spa/schema_serializer.rb` use `Moxml::Context`. Remaining gaps:

- Direct Nokogiri usage survives in exactly one place:
  `create_type_wrapper_xsd` and `resolve_type_prefix`
  (`lib/lutaml/xsd/spa/schema_serializer.rb`), including
  `require "nokogiri"`.
- The bundle does not include the leptris adapter, so Moxml's default
  adapter selection falls back to Nokogiri everywhere — including inside
  lutaml-model 0.8.x, which is itself built on Moxml.
- moxml 0.5.147 (pinned via lutaml-xsd#104) ships `Moxml::XSD`: an
  adapter-agnostic XSD validation facade over engines that implement one
  (leptris, nokogiri — "tier-1"). lutaml-xsd maintains a substantial
  hand-rolled validation stack (5 rules, 14 facet validators, 10
  base-type validators) that does not use it.

## 2. Goals

1. No direct Nokogiri usage in `lib/` — everything through Moxml.
2. Dev/CI runs the stack on the Leptris engine via the `leptris` gem
   (Gemfile-only; public dependency contract unchanged).
3. Use `Moxml::XSD` where it helps: a full-document engine fast-path in
   `Validation`, plus engine delegation for lexical and content-model
   checks where supported, with the Ruby rule engine remaining
   authoritative and the fallback everywhere else.
4. CLAUDE.md documents the Moxml-only XML stack.

## 3. Non-goals

- No replacement of the Ruby rule engine by engine validation (tier-1
  scope validates laxly outside named+typed top-level elements /
  one-level content-model descent / lexical checks — silent
  false-negatives are unacceptable).
- No runtime adapter dependency in the gemspec (moxml itself declares
  zero runtime deps; consumers bundle the adapters they want).
- `XsdSpecValidator` (schema-level spec compliance) keeps its own rules;
  `Moxml::XSD` validates instances, not schemas.
- Removing the `xsdvi` dependency (it requires `nokogiri ~> 1.16`, so
  nokogiri remains in the lockfile transitively; lutaml-xsd code simply
  stops touching it).

## 4. Dependency changes

| Change | Where | Status |
|---|---|---|
| `moxml ~> 0.5.147` pin | gemspec | PR #104 (patch release 1.1.13 follows) |
| `gem "leptris"` | Gemfile (dev) | this work |
| drop `gem "nokogiri"` | Gemfile | this work (stays in lock via xsdvi) |

Gemspec contract otherwise unchanged. moxml auto-selects leptris when
the gem is present (`Leptris::XML::Document.create` probe); no adapter
is hardcoded in lutaml-xsd.

## 5. Workstream A — finish the Moxml port

`spa/schema_serializer.rb`:

- Delete `require "nokogiri"`.
- `create_type_wrapper_xsd`: `Moxml::Context.new.parse(File.read(path))`;
  `doc.at_xpath("//xs:schema", ns)` (Moxml `xpath`/`at_xpath` accept
  namespace hashes exactly like Nokogiri);
  `schema.namespace_definitions.find { |nd| nd.href == XSD_NS }`;
  `doc.create_element("element")`; `element_node["name"] = ...`;
  `element_node["type"] = type_ref`;
  `element_node.namespace = xsd_ns_decl`; `schema.add_child(element_node)`;
  `doc.to_xml` into the Tempfile.
- `resolve_type_prefix`: same xpath + `namespace_definitions` mapping.
- Spec: the generated wrapper XSD must match current Nokogiri output
  (root `xs:schema`, wrapper `xs:element` in the XSD namespace, correct
  prefix resolution). Regression-gate with a byte-equivalence test
  captured before the port.

## 6. Workstream B — leptris in the bundle

- Add `gem "leptris"` to the Gemfile (dev/CI). Latest published:
  1.9.372.0.
- Verify `Moxml.new.config.adapter_name == :leptris` under the bundle;
  CI stays adapter-neutral (moxml picks leptris when present, nokogiri
  otherwise) so the suite runs both engines over time.

## 7. Workstream C — `Moxml::XSD` engine integration

### 7.1 New class `Lutaml::Xsd::Validation::EngineXsd`

One instance per `ValidationJob`, built from the job's `Moxml::Context`:

- `Moxml::XSD.supported?(context)` gates everything. Unsupported
  adapters (Oga/Ox/REXML) yield an inert engine (`nil`-equivalent); job
  behavior is unchanged.
- Compiles each schema source in `repository.all_schemas` via
  `context.xsd(source)`; schemas with non-nil `compile_error` are
  skipped and surface as warnings — the Ruby rules still judge them.
- `#validate(document)`: runs each compiled `Moxml::XSD::Schema#validate`,
  maps findings, returns them merged.
- Provenance: every mapped finding gets `code: "engine_validation"` so
  consumers can tell engine findings from rule findings.

### 7.2 Error mapping

`Moxml::XSD::ValidationError(message:, line:, column:, path:)` →
`Lutaml::Xsd::Validation::ValidationError` with
`severity: :error` and `location:` derived from line/column/path.
`to_s` keeps the `"<line>: <message>"` shape.

### 7.3 Job wiring

`ValidationJob#execute` gains a phase after `parse_xml`, gated by a new
config feature `:engine_validation` (default: enabled when supported).
Findings merge into the existing `ResultCollector`. A document is valid
only when both engines are silent — engine findings are additive, the
Ruby rule engine remains authoritative (laxness mitigation).

### 7.4 Delegated checks

An `EngineContext` (supported? flag + compiled schema handles) hangs off
the job and reaches validators through the existing registries:

- `validation/base_types/*`: when the engine is available,
  `Moxml::XSD.builtin_valid?` / `schema.simple_valid?` run first; Ruby
  logic stays the fallback (other adapters, engine gaps).
- `validation/rules/content_model_validation_rule.rb` and
  `occurrence_validation_rule.rb`: consult
  `schema.content_valid?(element_name, children)` the same way.
- No validator public interface changes; delegation is internal and
  capability-gated (OCP: engine support is a registry concern, not a
  per-validator branch sprawl).

## 8. Testing

Real objects throughout (no doubles, per standing rules):

- Supported-engine shared context: engine tests run where leptris is
  installed, skip cleanly elsewhere (`Moxml::XSD.supported?` probe).
- Fallback specs: adapter forced to REXML; behavior byte-identical to
  today (engine inert, no new findings, registries use Ruby paths).
- Port specs: wrapper-XSD byte-equivalence vs. the captured Nokogiri
  baseline.
- Mapping specs: each `Moxml::XSD::ValidationError` field lands in the
  right `Validation::ValidationError` field; merge semantics with Ruby
  findings; `compile_error` → warning path.
- Delegation specs: engine path and Ruby path agree on valid/invalid
  fixtures from `spec/fixtures`; disagreement is a test failure.

## 9. Risks

- Tier-1 laxness → engine findings additive only; Ruby engine
  authoritative; documented in CLAUDE.md and YARD.
- Multi-schema repositories (imports, RNG→XSD-converted files) may
  under-report in the engine → acceptable because findings are additive;
  cross-schema resolution stays the Ruby engine's job.
- Moxml serialization nuances in the wrapper-XSD port → byte-equivalence
  spec catches drift.
- leptris platform coverage → Gemfile-only today; runtime adoption is a
  separate, owner-decided decision.

## 10. Rollout order

1. PR #104 merged + 1.1.13 patch release (moxml pin only).
2. Workstreams A + B (port + leptris in Gemfile) — one PR.
3. Workstream C (engine integration) — one PR.
4. CLAUDE.md update lands with (2)/(3).
