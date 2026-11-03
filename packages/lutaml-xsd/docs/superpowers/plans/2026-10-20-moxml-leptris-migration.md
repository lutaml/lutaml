# Moxml/leptris Migration + Moxml::XSD Engine Integration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate the last direct Nokogiri usage in lutaml-xsd, run the dev/CI stack on the Leptris engine, and integrate `Moxml::XSD` engine validation as an additive fast-path with lexical/content-model delegation.

**Architecture:** Two PRs. PR 1 (`feat/moxml-port-leptris`) ports `create_type_wrapper_xsd`/`resolve_type_prefix` to Moxml behind a characterization spec, then swaps the Gemfile to leptris. PR 2 (`feat/moxml-xsd-engine-validation`) adds `Validation::EngineContext` (compiled `Moxml::XSD::Schema` handles + capability probe + finding mapping), wires it into `ValidationJob` as a config-gated phase, and delegates lexical/content checks inside `TypeValidationRule`/`ContentModelValidationRule` via `options[:engine_context]`.

**Tech Stack:** Ruby >= 3.0, moxml ~> 0.5.147 (`Moxml::XSD`, leptris adapter), leptris (Gemfile dev-only), RSpec.

**Spec:** `docs/superpowers/specs/2026-10-20-moxml-leptris-migration-design.md` (posted as lutaml/lutaml-xsd#105)

## Global Constraints

- NEVER use `double()` in specs — real objects only (standing rule). Engine specs use real leptris; they skip when `Moxml::XSD.supported?` is false.
- NEVER call private methods via `send`. Both ported serializer methods are public — spec them directly.
- Engine findings are ADDITIVE (`code: "engine_validation"`); the Ruby rule engine stays authoritative. Never replace Ruby rules with engine results.
- `leptris` is Gemfile (dev) ONLY. The gemspec gains NO adapter dependencies. Do not touch gemspec in either PR.
- No commits to main; no AI attribution in commits; stage files by explicit path only; PR bodies via `--body-file`.
- Config flag name is exactly `engine_validation`, nested at `validation.features.engine_validation`; default enabled (`feature_enabled?` returns true unless explicitly false).
- Full-suite gates: `bundle exec rspec` (expect 0 failures) and `bundle exec rubocop` before every push.

---

## PR 1 — `feat/moxml-port-leptris`

### Task 1: Characterization spec for the wrapper-XSD methods

**Files:**
- Create: `spec/lutaml/xsd/spa/schema_serializer_wrapper_spec.rb`

**Interfaces:**
- Consumes: `Lutaml::Xsd::Spa::SchemaSerializer.new(repository_or_package, config = {})` (repository unused by the methods under test — pass `nil`), `#create_type_wrapper_xsd(type_name, original_file_path) -> String (tempfile path)`, `#resolve_type_prefix(type_name, doc, ns) -> String`.
- Produces: the fixture path helper `write_schema_xsd` and expected semantics that Task 2's port must preserve verbatim.

- [ ] **Step 1: Write the characterization spec**

```ruby
# frozen_string_literal: true

require "spec_helper"
require "moxml"
require "tempfile"

RSpec.describe Lutaml::Xsd::Spa::SchemaSerializer do
  subject(:serializer) { described_class.new(nil, { verbose: false }) }

  let(:schema_xml) do
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"
                 xmlns:tns="http://example.com/test"
                 targetNamespace="http://example.com/test">
        <xs:complexType name="Address">
          <xs:sequence>
            <xs:element name="street" type="xs:string"/>
          </xs:sequence>
        </xs:complexType>
        <xs:element name="address" type="tns:Address"/>
      </xs:schema>
    XML
  end

  let(:schema_path) do
    file = Tempfile.new(["characterization", ".xsd"])
    file.write(schema_xml)
    file.close
    file.path
  end

  def wrapper_document(path)
    Moxml::Context.new.parse(File.read(path))
  end

  describe "#create_type_wrapper_xsd" do
    it "wraps a schema-level type in a synthetic root element" do
      wrapper_path = serializer.create_type_wrapper_xsd("Address", schema_path)
      doc = wrapper_document(wrapper_path)

      expect(doc.root.name).to eq("schema")
      added = doc.xpath("//element").map(&:name)
      expect(added).to include("_diagram_root_Address")
      expect(File.read(wrapper_path)).to include("complexType")
      expect(File.read(wrapper_path)).to include('name="street"')
    end

    it "returns the original path when no xs:schema exists" do
      no_schema = Tempfile.new(["no-schema", ".xsd"])
      no_schema.write("<not-a-schema/>")
      no_schema.close

      expect(serializer.create_type_wrapper_xsd("Address", no_schema.path))
        .to eq(no_schema.path)
    ensure
      no_schema.unlink
    end
  end

  describe "#resolve_type_prefix" do
    it "prefixes types defined in the schema's targetNamespace" do
      doc = Moxml::Context.new.parse(schema_xml)
      ns = { "xs" => "http://www.w3.org/2001/XMLSchema" }

      expect(serializer.resolve_type_prefix("Address", doc, ns))
        .to eq("tns:Address")
    end

    it "returns the bare name for unknown types" do
      doc = Moxml::Context.new.parse(schema_xml)
      ns = { "xs" => "http://www.w3.org/2001/XMLSchema" }

      expect(serializer.resolve_type_prefix("xs:string", doc, ns))
        .to eq("xs:string")
    end
  end
end
```

- [ ] **Step 2: Run it against the current (Nokogiri) implementation**

Run: `bundle exec rspec spec/lutaml/xsd/spa/schema_serializer_wrapper_spec.rb`
Expected: PASS (this characterizes today's behavior). If a semantic assertion fails, the assertion is wrong — fix the spec, not the code. Do not proceed until green.

- [ ] **Step 3: Commit**

```bash
git add spec/lutaml/xsd/spa/schema_serializer_wrapper_spec.rb
git commit -m "Add characterization spec for wrapper XSD generation"
```

### Task 2: Port `create_type_wrapper_xsd` and `resolve_type_prefix` to Moxml

**Files:**
- Modify: `lib/lutaml/xsd/spa/schema_serializer.rb:8` (delete `require "nokogiri"`), `:503-570` (the two methods)

**Interfaces:**
- Consumes: Moxml `Context#parse`, `Document#at_xpath(expr, ns_hash)`, `Document#create_element(name)`, `Element#namespace_definitions` (`#href`, `#prefix`), `Element#namespace=(ns_or_hash)`, `Node#add_child`, `Document#to_xml`.
- Produces: identical behavior to Task 1's characterization spec.

- [ ] **Step 1: Replace the Nokogiri implementation**

In `create_type_wrapper_xsd` (keep the method contract and all comments about xsdvi):

```ruby
def create_type_wrapper_xsd(type_name, original_file_path)
  doc = Moxml::Context.new.parse(File.read(original_file_path))
  ns = { "xs" => "http://www.w3.org/2001/XMLSchema" }
  schema = doc.at_xpath("//xs:schema", ns)

  unless schema
    warn "xsdvi: No xs:schema found in '#{original_file_path}'" if config[:verbose]
    return original_file_path
  end

  wrapper_name = "_diagram_root_#{type_name}"
  type_ref = resolve_type_prefix(type_name, doc, ns)

  xsd_ns = "http://www.w3.org/2001/XMLSchema"
  xsd_ns_decl = schema.namespace_definitions.find do |nd|
    nd.href == xsd_ns
  end

  element_node = doc.create_element("element")
  element_node.namespace = xsd_ns_decl if xsd_ns_decl
  element_node["name"] = wrapper_name
  element_node["type"] = type_ref

  schema.add_child(element_node)

  tmp = Tempfile.new(["xsdvi-wrapper-", ".xsd"])
  tmp.write(doc.to_xml)
  tmp.close
  tmp.path
end
```

In `resolve_type_prefix` the body is already namespace-API-compatible; verify `schema["targetNamespace"]`, `doc.xpath(...)` and `schema.namespace_definitions` work unchanged (they do in Moxml). Adjust only if a call site raises.

- [ ] **Step 2: Remove `require "nokogiri"` (line 8) and verify no Nokogiri references remain in lib/**

Run: `grep -rn "Nokogiri\|nokogiri" lib/ | grep -v "\.bak"`
Expected: only the two historical comments in `package_builder.rb:70,204` mentioning Nokogiri in prose. Update those comment strings to say "Moxml nodes" / "XML nodes" since they describe XmlElement contents.

- [ ] **Step 3: Run the characterization spec, then the full suite**

Run: `bundle exec rspec spec/lutaml/xsd/spa/schema_serializer_wrapper_spec.rb && bundle exec rspec`
Expected: PASS everywhere (suite currently runs on the Nokogiri moxml adapter — leptris is not bundled yet).

- [ ] **Step 4: Commit**

```bash
git add lib/lutaml/xsd/spa/schema_serializer.rb
git commit -m "Port wrapper XSD generation from Nokogiri to Moxml"
```

### Task 3: Bundle leptris, drop nokogiri from the Gemfile

**Files:**
- Modify: `Gemfile` (remove `gem "nokogiri"`, add `gem "leptris"`)

**Interfaces:**
- Consumes: moxml default adapter selection (leptris when `Leptris::XML::Document.create` responds).
- Produces: bundle resolves leptris; `Moxml.new.config.adapter_name == :leptris`.

- [ ] **Step 1: Edit the Gemfile** — delete the `gem "nokogiri"` line, add `gem "leptris"` in its alphabetical position.

- [ ] **Step 2: Refresh the lockfile and verify the adapter**

Run: `bundle install && bundle exec ruby -e 'require "moxml"; puts Moxml.new.config.adapter_name'`
Expected: `:leptris` (nokogiri remains in the lockfile only via xsdvi `~> 1.16`).

- [ ] **Step 3: Run the FULL suite on the leptris engine**

Run: `bundle exec rspec`
Expected: 0 failures. This is the load-bearing verification — every parse/serialize/XPath in the suite now executes on leptris via moxml. Any failure is a moxml-adapter behavior difference: fix by adjusting the code (not by weakening specs), and if a genuine moxml/leptris defect appears, stop and report it instead of working around it.

- [ ] **Step 4: Commit, push, open PR**

```bash
git add Gemfile
git commit -m "Run development bundle on leptris, drop direct nokogiri"
git push -u origin feat/moxml-port-leptris
printf 'Completes the Moxml migration (workstreams A+B of #105):\n\n- Port `create_type_wrapper_xsd`/`resolve_type_prefix` from Nokogiri to Moxml (characterization-gated)\n- No direct Nokogiri usage remains in lib/ (xsdvi keeps it in the lockfile transitively)\n- Gemfile: leptris in, nokogiri out — dev/CI runs the moxml default adapter chain on leptris\n- Full suite green on the leptris engine\n' > /tmp/pr1-body.md
gh pr create --title "Complete Moxml migration and run on leptris" --body-file /tmp/pr1-body.md
```

### Task 4: CLAUDE.md — document the Moxml-only XML stack

**Files:**
- Modify: `CLAUDE.md` (new section after "Key Patterns")

- [ ] **Step 1: Add the section**

```markdown
### XML Stack: Moxml Only

All XML handling goes through `Moxml::Context` (moxml ~> 0.5.147). Never
require or call Nokogiri/REXML/Ox directly in `lib/` — xsdvi keeps nokogiri
in the lockfile transitively, but our code does not touch it.

- Adapter selection is moxml's: leptris when bundled (dev Gemfile), nokogiri
  fallback otherwise. No adapter is hardcoded here.
- `Moxml::XSD` (engine XSD validation, tier-1: leptris/nokogiri) backs the
  validation fast-path — see `lib/lutaml/xsd/validation/engine_context.rb`.
  Engine findings are additive (`code: "engine_validation"`); the Ruby rule
  engine remains authoritative because tier-1 validates laxly outside its
  scope.
```

- [ ] **Step 2: Commit on the PR branch and push**

```bash
git add CLAUDE.md
git commit -m "Document Moxml-only XML stack in CLAUDE.md"
git push
```

---

## PR 2 — `feat/moxml-xsd-engine-validation`

Branch from updated `main` after PR 1 merges.

### Task 5: `Validation::EngineContext`

**Files:**
- Create: `lib/lutaml/xsd/validation/engine_context.rb`
- Create: `spec/lutaml/xsd/validation/engine_context_spec.rb`
- Modify: `lib/lutaml/xsd/validation/validator.rb` (autoload-adjacent require of the new file at top, following its existing `require_relative` block)

**Interfaces:**
- Produces (consumed by Tasks 6-8):
  - `EngineContext.compile(repository, context: Moxml::Context.new) -> EngineContext or nil` — nil when `Moxml::XSD.supported?(context)` is false.
  - `#supported? -> Boolean` (true when at least one schema compiled)
  - `#findings_for(xml_content) -> Array<Lutaml::Xsd::Validation::ValidationError>` with `code: "engine_validation"`, `line_number:` from the engine finding, `location:` from `path`.
  - `#builtin_valid?(builtin_name, lexical) -> true/false/nil` (nil = engine could not answer; caller falls back)
  - `#simple_valid?(type_name, lexical) -> true/false/nil`
  - `#content_valid?(element_name, children) -> true/false/nil`
  - `ENGINE_CODE = "engine_validation"`

- [ ] **Step 1: Write the failing spec** (skip-gated shared context; real leptris)

```ruby
# frozen_string_literal: true

require "spec_helper"
require "moxml"

RSpec.describe Lutaml::Xsd::Validation::EngineContext do
  let(:context) { Moxml::Context.new }
  let(:xsd_source) do
    <<~XML
      <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <xs:element name="note" type="xs:string"/>
      </xs:schema>
    XML
  end
  let(:repository) do
    instance = nil
    schema = Lutaml::Xml::Schema::Xsd.parse(xsd_source)
    instance = Class.new do
      define_method(:all_schemas) { { "http://example.com/test" => schema } }
    end.new
    instance
  end

  def compile
    described_class.compile(repository, context: context)
  end

  it "compiles when the adapter ships an XSD validator", if: Moxml::XSD.supported?(Moxml::Context.new) do
    engine = compile
    expect(engine).to be_a(described_class)
    expect(engine).to be_supported
  end

  it "returns nil on adapters without an XSD validator", unless: Moxml::XSD.supported?(Moxml::Context.new) do
    expect(compile).to be_nil
  end

  it "maps engine findings to Validation::ValidationError", if: Moxml::XSD.supported?(Moxml::Context.new) do
    engine = compile
    findings = engine.findings_for("<note>12</note>")
    expect(findings).to all(be_a(Lutaml::Xsd::Validation::ValidationError))
    expect(findings.map(&:code)).to all(eq(described_class::ENGINE_CODE))
    expect(findings).to all(be_error)
  end

  it "reports no findings for valid documents", if: Moxml::XSD.supported?(Moxml::Context.new) do
    engine = compile
    expect(engine.findings_for("<note>hello</note>")).to be_empty
  end
end
```

Note: `repository` here is an anonymous-class stand-in exposing the one method EngineContext consumes (`all_schemas` — a Hash of `Lutaml::Xml::Schema::Xsd::Schema` keyed by namespace, values serialized with `to_xml`). It is a real object, not a double. `Moxml::XSD.supported?` raises on adapters without a compiled validator constant, so guard: `defined?(Moxml::XSD) && (Moxml::XSD.supported?(ctx) rescue false)` if the plain call raises in the `if:`/`unless:` guards.

- [ ] **Step 2: Run to verify failure**

Run: `bundle exec rspec spec/lutaml/xsd/validation/engine_context_spec.rb`
Expected: FAIL — `LoadError`/`NameError`, class does not exist.

- [ ] **Step 3: Implement EngineContext**

```ruby
# frozen_string_literal: true

require "moxml"

module Lutaml
  module Xsd
    module Validation
      # EngineContext adapts Moxml::XSD (engine-native XSD validation on
      # leptris/nokogiri) to lutaml-xsd's validation stack.
      #
      # Engine findings are additive: tier-1 engine scope validates laxly
      # outside named+typed top-level elements / one-level content-model
      # descent / lexical checks, so the Ruby rule engine stays
      # authoritative. All query methods return nil (not false) when the
      # engine cannot answer, and callers fall back to Ruby logic.
      class EngineContext
        ENGINE_CODE = "engine_validation"

        attr_reader :context, :schemas

        class << self
          # Compile repository schemas for the current adapter.
          #
          # @param repository [#all_schemas] Schema repository
          # @param context [Moxml::Context] Adapter context
          # @return [EngineContext, nil] nil when the adapter has no engine
          def compile(repository, context: Moxml::Context.new)
            return nil unless xsd_supported?(context)

            schemas = repository.all_schemas.values.filter_map do |schema|
              compile_schema(context, schema)
            end
            new(context, schemas)
          end

          def xsd_supported?(context)
            Moxml::XSD.supported?(context)
          rescue Moxml::NotImplementedError, NameError
            false
          end

          # Map a Moxml::XSD::ValidationError into the lutaml-xsd error type
          def map_finding(finding)
            ValidationError.new(
              code: ENGINE_CODE,
              message: finding.message,
              severity: :error,
              location: finding.path,
              line_number: finding.line,
              context: { column: finding.column }.compact,
            )
          end

          private

          def compile_schema(context, schema)
            compiled = context.xsd(schema.to_xml)
            compiled.compile_error ? nil : compiled
          rescue Moxml::NotImplementedError, Moxml::ParseError, StandardError
            nil
          end
        end

        def initialize(context, schemas)
          @context = context
          @schemas = schemas
        end

        def supported?
          !@schemas.empty?
        end

        # Validate raw XML against all compiled schemas.
        #
        # @param xml_content [String]
        # @return [Array<Validation::ValidationError>]
        def findings_for(xml_content)
          @schemas.flat_map { |schema| schema.validate(xml_content) }
                  .map { |finding| self.class.map_finding(finding) }
        end

        # Lexical check against the built-in type table ("xs:NAME" spelling).
        # @return [Boolean, nil] nil when the engine cannot answer
        def builtin_valid?(builtin_name, lexical)
          Moxml::XSD.builtin_valid?(@context, builtin_name, lexical)
        rescue ArgumentError, Moxml::NotImplementedError, StandardError
          nil
        end

        # Lexical check against a schema's named simpleType.
        # @return [Boolean, nil] nil when no compiled schema knows the type
        def simple_valid?(type_name, lexical)
          @schemas.each do |schema|
            answer = schema.simple_valid?(type_name, lexical)
            return answer
          rescue StandardError
            next
          end
          nil
        end

        # Content-model check for one element's children (Moxml nodes).
        # @return [Boolean, nil] nil when the engine cannot answer
        def content_valid?(element_name, children)
          @schemas.each do |schema|
            answer = schema.content_valid?(element_name, children)
            return answer
          rescue StandardError
            next
          end
          nil
        end
      end
    end
  end
end
```

Add `require_relative "engine_context"` to the top require block of `lib/lutaml/xsd/validation/validator.rb`.

- [ ] **Step 4: Run the spec — green**

Run: `bundle exec rspec spec/lutaml/xsd/validation/engine_context_spec.rb`
Expected: PASS (leptris bundled → compile/tests run on real engine).

- [ ] **Step 5: Commit**

```bash
git add lib/lutaml/xsd/validation/engine_context.rb lib/lutaml/xsd/validation/validator.rb spec/lutaml/xsd/validation/engine_context_spec.rb
git commit -m "Add EngineContext bridging Moxml::XSD engine validation"
```

### Task 6: ValidationJob engine phase + `engine_validation` feature flag

**Files:**
- Modify: `lib/lutaml/xsd/validation/validation_job.rb` (`execute` + new private method)
- Modify: `config/validation.yml:29` (`features:` — add `engine_validation: true`)
- Modify: `lib/lutaml/xsd/validation/validation_configuration.rb` (`default_config_hash` features hash — add `"engine_validation" => true`)
- Test: `spec/lutaml/xsd/validation/validation_job_spec.rb` (extend)

**Interfaces:**
- Consumes: `EngineContext.compile(repository)` / `#findings_for(xml_content)` / `#supported?` (Task 5); `ResultCollector#add_error`.
- Produces: engine findings appear in `ValidationResult` with `code: "engine_validation"`; disable via `features: { engine_validation: false }`.

- [ ] **Step 1: Write the failing spec** (reuse Task 5's real-schema fixture style; build the job with a real repository stand-in)

```ruby
describe "engine validation phase" do
  let(:engine_supported) do
    Lutaml::Xsd::Validation::EngineContext.xsd_supported?(Moxml::Context.new)
  end

  it "adds engine findings for invalid documents", if: engine_supported do
    job = described_class.new(
      xml_content: "<note>12</note>",
      repository: repository,
      rule_registry: rule_registry,
      config: Lutaml::Xsd::Validation::ValidationConfiguration.default,
    )
    result = job.execute
    codes = result.errors.map(&:code)
    expect(codes).to include("engine_validation")
  end

  it "skips engine validation when the feature is disabled", if: engine_supported do
    config = Lutaml::Xsd::Validation::ValidationConfiguration.new(
      { "validation" => { "features" => { "engine_validation" => false } } },
    )
    job = described_class.new(
      xml_content: "<note>12</note>",
      repository: repository,
      rule_registry: rule_registry,
      config: config,
    )
    result = job.execute
    expect(result.errors.map(&:code)).not_to include("engine_validation")
  end

  it "adds no engine findings for valid documents", if: engine_supported do
    job = described_class.new(
      xml_content: "<note>hello</note>",
      repository: repository,
      rule_registry: rule_registry,
      config: Lutaml::Xsd::Validation::ValidationConfiguration.default,
    )
    result = job.execute
    expect(result.errors.map(&:code)).not_to include("engine_validation")
  end
end
```

(`rule_registry` = `Lutaml::Xsd::Validation::RuleRegistry.new(config)` — the default pipeline registers no rules, matching `Validator#build_rule_registry`.)

- [ ] **Step 2: Run — expect FAIL** (`engine_validation` code never appears).

- [ ] **Step 3: Wire the phase into `execute`** — insert after `parse_xml` / before `validate_structure`:

```ruby
run_engine_validation if @config.feature_enabled?(:engine_validation)
```

Private method:

```ruby
# Run engine-native XSD validation (Moxml::XSD) when the adapter
# supports it. Findings are additive to rule findings.
def run_engine_validation
  @engine_context ||= EngineContext.compile(@repository)
  return unless @engine_context&.supported?

  @engine_context.findings_for(@xml_content).each do |finding|
    @result_collector.add_error(finding)
  end
rescue StandardError => e
  @result_collector.add_warning(
    ValidationError.new(
      code: "engine_validation_unavailable",
      message: "Engine validation skipped: #{e.message}",
      severity: :warning,
    ),
  )
end
```

- [ ] **Step 4: Add the flag to `config/validation.yml`** under `features:` and to `default_config_hash`'s features hash: `"engine_validation" => true`.

- [ ] **Step 5: Run job spec + config spec, then full suite**

Run: `bundle exec rspec spec/lutaml/xsd/validation/ && bundle exec rspec`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/lutaml/xsd/validation/validation_job.rb lib/lutaml/xsd/validation/validation_configuration.rb config/validation.yml spec/lutaml/xsd/validation/validation_job_spec.rb
git commit -m "Run Moxml::XSD engine validation as an additive ValidationJob phase"
```

### Task 7: Lexical delegation in `TypeValidationRule`

**Files:**
- Modify: `lib/lutaml/xsd/validation/rules/type_validation_rule.rb`
- Test: `spec/lutaml/xsd/validation/rules/type_validation_rule_spec.rb` (extend or create)

**Interfaces:**
- Consumes: `EngineContext#builtin_valid?("xs:string", lexical) -> true/false/nil`, `#simple_valid?(type_name, lexical)`, `#supported?` (Task 5). Rules receive the engine via constructor options: `TypeValidationRule.new(engine_context: engine)`.
- Produces: delegation only; `validate(xml_element, schema_element, collector)` signature unchanged; nil answers fall back to existing Ruby validators.

- [ ] **Step 1: Failing spec** — validate `<note>12</note>` against `type="xs:string"` with a real compiled EngineContext (Task 5 fixture): expect the engine path to answer and a Ruby-registry validator NOT to be consulted. Assert observable behavior: error/no-error outcome identical to the Ruby path for valid and invalid lexical values, and that constructing the rule with `engine_context:` + forcing `engine.builtin_valid?` to receive the call is NOT asserted (no interaction testing). Concrete assertions:

```ruby
it "accepts valid lexical values via the engine path" do
  rule = described_class.new(engine_context: engine)
  expect { rule.validate(element_with("hello"), xs_string_element, collector) }
    .not_to change { collector.errors.count }
end

it "rejects invalid lexical values via the engine path" do
  rule = described_class.new(engine_context: engine)
  rule.validate(element_with(12), xs_string_element, collector)
  expect(collector.errors.map(&:code)).to include(/type/)
end
```

- [ ] **Step 2: Run — FAIL** (rule ignores `engine_context`).

- [ ] **Step 3: Implement delegation** — in `validate_builtin_type`, before consulting `BaseTypeValidatorRegistry`:

```ruby
engine = @options[:engine_context]
if engine&.supported?
  answer = engine.builtin_valid?(
    "xs:#{local_name(type_name)}", value
  )
  return handle_builtin_answer(xml_element, type_name, answer, collector) unless answer.nil?
end
```

with

```ruby
def handle_builtin_answer(xml_element, type_name, answer, collector)
  return if answer

  collector.add_error(
    ValidationError.new(
      code: "type_validation_error",
      message: "'#{value}' is not a valid #{type_name}",
      severity: :error,
      location: xml_element.path,
    ),
  )
end

def local_name(type_name)
  type_name.to_s.split(":").last
end
```

In `validate_simple_type_content`, for named simple types: consult `engine.simple_valid?(type_name, value)` first (nil → existing facet path). Mirror the exact existing error codes/messages when delegating so consumers see no difference — read the current bodies first and reuse their message construction.

- [ ] **Step 4: Run rule spec + full suite — green.** Commit:

```bash
git add lib/lutaml/xsd/validation/rules/type_validation_rule.rb spec/lutaml/xsd/validation/rules/type_validation_rule_spec.rb
git commit -m "Delegate lexical type checks to the engine when supported"
```

### Task 8: Content-model delegation in `ContentModelValidationRule`

**Files:**
- Modify: `lib/lutaml/xsd/validation/rules/content_model_validation_rule.rb`
- Test: `spec/lutaml/xsd/validation/rules/content_model_validation_rule_spec.rb`

**Interfaces:**
- Consumes: `EngineContext#content_valid?(element_name, moxml_children) -> true/false/nil` (Task 5); `xml_element.moxml_element.children` for the Moxml node list.
- Produces: same contract as Task 7 — `validate(xml_element, schema_def, collector)` unchanged, nil falls back to the Ruby sequence/choice/all walk.

- [ ] **Step 1: Failing spec** — same shape as Task 7: valid child order accepted, invalid child order rejected, engine-present rule behaves identically to Ruby path on fixtures from `spec/fixtures` (real objects).

- [ ] **Step 2: Run — FAIL.**

- [ ] **Step 3: Implement** — at the top of `validate`, before dispatching to `validate_sequence`/`validate_choice`/`validate_all`:

```ruby
engine = @options[:engine_context]
if engine&.supported?
  answer = engine.content_valid?(
    xml_element.name, xml_element.moxml_element.children.to_a
  )
  unless answer.nil?
    add_content_error(xml_element, collector) unless answer
    return
  end
end
```

`add_content_error` mirrors the rule's existing error code/message construction (read the file; reuse it exactly).

- [ ] **Step 4: Run rule spec + full suite — green.** Commit:

```bash
git add lib/lutaml/xsd/validation/rules/content_model_validation_rule.rb spec/lutaml/xsd/validation/rules/content_model_validation_rule_spec.rb
git commit -m "Delegate content-model checks to the engine when supported"
```

### Task 9: Fallback guarantees, full gates, PR

**Files:**
- Create: `spec/lutaml/xsd/validation/engine_fallback_spec.rb`
- Modify: `CLAUDE.md` (only if engine notes changed since Task 4)

**Interfaces:**
- Consumes: everything above. `Moxml::Context.new(:rexml)` forces the non-engine adapter.

- [ ] **Step 1: Write fallback specs**

```ruby
RSpec.describe "engine validation fallback" do
  let(:rexml_context) { Moxml::Context.new(:rexml) }

  it "compiles to nil on REXML (no engine validator)" do
    expect(Lutaml::Xsd::Validation::EngineContext.xsd_supported?(rexml_context)).to be(false)
    expect(Lutaml::Xsd::Validation::EngineContext.compile(repository, context: rexml_context)).to be_nil
  end

  it "runs a full validation job without engine findings on REXML" do
    job = Lutaml::Xsd::Validation::ValidationJob.new(
      xml_content: "<note>12</note>",
      repository: repository,
      rule_registry: Lutaml::Xsd::Validation::RuleRegistry.new(config),
      config: config,
    )
    result = job.execute
    expect(result.errors.map(&:code)).not_to include("engine_validation")
  end
end
```

- [ ] **Step 2: Full gates** — `bundle exec rspec` (0 failures) and `bundle exec rubocop` (clean). Fix findings, re-run.

- [ ] **Step 3: Commit, push, open PR** (the `feat/moxml-xsd-engine-validation` branch was created from updated main before Task 5)

```bash
git add spec/lutaml/xsd/validation/engine_fallback_spec.rb CLAUDE.md
git commit -m "Add non-engine adapter fallback specs"
git push -u origin feat/moxml-xsd-engine-validation
printf 'Integrates Moxml::XSD engine validation (workstream C of #105):\n\n- `Validation::EngineContext`: capability-gated compiled-schema bridge (leptris/nokogiri tier-1)\n- `ValidationJob` phase `engine_validation` (default on when supported), findings additive with `code: "engine_validation"`\n- Lexical + content-model checks delegate to the engine via `options[:engine_context]`; nil answers fall back to the Ruby rule engine\n- REXML/Oga/Ox adapters unchanged (compile returns nil)\n' > /tmp/pr2-body.md
gh pr create --title "Integrate Moxml::XSD engine validation" --body-file /tmp/pr2-body.md
```
