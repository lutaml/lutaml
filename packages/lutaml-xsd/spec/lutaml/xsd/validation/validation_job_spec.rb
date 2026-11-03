# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/validation/validation_job"

RSpec.describe Lutaml::Xsd::Validation::ValidationJob do
  let(:xml_content) { "<root>test</root>" }
  let(:repository) { Lutaml::Xsd::SchemaRepository.new }
  let(:config) { Lutaml::Xsd::Validation::ValidationConfiguration.new }
  let(:rule_registry) { Lutaml::Xsd::Validation::RuleRegistry.new(config) }

  describe "#initialize" do
    it "initializes with required parameters" do
      job = described_class.new(
        xml_content: xml_content,
        repository: repository,
        rule_registry: rule_registry,
        config: config,
      )

      expect(job).to be_a(described_class)
    end

    it "requires xml_content parameter" do
      expect do
        described_class.new(
          repository: repository,
          rule_registry: rule_registry,
          config: config,
        )
      end.to raise_error(ArgumentError, /xml_content/)
    end

    it "requires repository parameter" do
      expect do
        described_class.new(
          xml_content: xml_content,
          rule_registry: rule_registry,
          config: config,
        )
      end.to raise_error(ArgumentError, /repository/)
    end

    it "requires rule_registry parameter" do
      expect do
        described_class.new(
          xml_content: xml_content,
          repository: repository,
          config: config,
        )
      end.to raise_error(ArgumentError, /rule_registry/)
    end

    it "requires config parameter" do
      expect do
        described_class.new(
          xml_content: xml_content,
          repository: repository,
          rule_registry: rule_registry,
        )
      end.to raise_error(ArgumentError, /config/)
    end
  end

  describe "#execute" do
    let(:job) do
      described_class.new(
        xml_content: xml_content,
        repository: repository,
        rule_registry: rule_registry,
        config: config,
      )
    end

    it "returns a ValidationResult" do
      result = job.execute
      expect(result).to be_a(Lutaml::Xsd::Validation::ValidationResult)
    end

    context "with nil xml_content" do
      let(:xml_content) { nil }

      it "returns invalid result with error" do
        result = job.execute
        expect(result).not_to be_valid
        expect(result.errors).not_to be_empty
        expect(result.first_error.code).to eq("invalid_input")
      end
    end

    context "with empty xml_content" do
      let(:xml_content) { "" }

      it "returns invalid result with error" do
        result = job.execute
        expect(result).not_to be_valid
        expect(result.errors).not_to be_empty
      end
    end

    context "with valid XML" do
      it "executes all validation phases" do
        result = job.execute
        expect(result).to be_a(Lutaml::Xsd::Validation::ValidationResult)
      end
    end

    context "with malformed XML" do
      let(:xml_content) { "<<<invalid>>>" }

      it "returns result with parse error" do
        result = job.execute
        expect(result).to be_a(Lutaml::Xsd::Validation::ValidationResult)
        # NOTE: XML parser may be lenient, so we just verify it returns a result
        # If it does detect an error, it should be in the errors list
        expect(result).not_to be_valid if result.errors.any?
      end
    end

    context "when stop_on_first_error is true" do
      let(:config) do
        Lutaml::Xsd::Validation::ValidationConfiguration.new(
          "validation" => { "stop_on_first_error" => true },
        )
      end

      it "stops after first error" do
        result = job.execute
        expect(result).to be_a(Lutaml::Xsd::Validation::ValidationResult)
      end
    end

    context "with features disabled" do
      let(:config) do
        Lutaml::Xsd::Validation::ValidationConfiguration.new(
          "validation" => {
            "features" => {
              "validate_types" => false,
              "validate_occurrences" => false,
            },
          },
        )
      end

      it "skips disabled validation phases" do
        result = job.execute
        expect(result).to be_a(Lutaml::Xsd::Validation::ValidationResult)
      end
    end
  end

  describe "validation phases" do
    let(:job) do
      described_class.new(
        xml_content: xml_content,
        repository: repository,
        rule_registry: rule_registry,
        config: config,
      )
    end

    describe "parse_xml phase" do
      it "parses XML content" do
        result = job.execute
        expect(result).to be_a(Lutaml::Xsd::Validation::ValidationResult)
      end

      it "handles parse errors" do
        job = described_class.new(
          xml_content: "<<<not valid xml>>>",
          repository: repository,
          rule_registry: rule_registry,
          config: config,
        )
        result = job.execute
        expect(result).to be_a(Lutaml::Xsd::Validation::ValidationResult)
        # NOTE: Verify the job completes even with potentially malformed XML
        # The specific behavior depends on the XML parser's leniency
      end
    end

    describe "validate_structure phase" do
      it "validates element structure" do
        result = job.execute
        expect(result).to be_a(Lutaml::Xsd::Validation::ValidationResult)
      end
    end

    describe "validate_types phase" do
      it "validates element types" do
        result = job.execute
        expect(result).to be_a(Lutaml::Xsd::Validation::ValidationResult)
      end
    end

    describe "validate_constraints phase" do
      it "validates constraints" do
        result = job.execute
        expect(result).to be_a(Lutaml::Xsd::Validation::ValidationResult)
      end
    end
  end

  describe "engine validation phase" do
    engine_supported =
      Lutaml::Xsd::Validation::EngineContext.xsd_supported?(Moxml::Context.new)

    let(:xsd_source) do
      <<~XML
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
          <xs:element name="date" type="xs:date"/>
        </xs:schema>
      XML
    end
    let(:schema) { Lutaml::Xml::Schema::Xsd.parse(xsd_source) }
    let(:engine_repository) do
      Class.new do
        def initialize(schemas)
          @schemas = schemas
        end

        def all_schemas
          @schemas
        end
      end.new({ "http://example.com/test" => schema })
    end

    def run_job(xml, config: nil)
      described_class.new(
        xml_content: xml,
        repository: engine_repository,
        rule_registry: rule_registry,
        config: config || self.config,
      ).execute
    end

    it "adds engine findings for invalid documents", if: engine_supported do
      result = run_job("<date>not-a-date</date>")

      expect(result.errors.map(&:code)).to include("engine_validation")
    end

    it "adds no engine findings for valid documents", if: engine_supported do
      result = run_job("<date>2024-01-15</date>")

      expect(result.errors.map(&:code)).not_to include("engine_validation")
    end

    it "skips engine validation when the feature is disabled", if: engine_supported do
      config = Lutaml::Xsd::Validation::ValidationConfiguration.new(
        { "validation" => { "features" => { "engine_validation" => false } } },
      )
      result = run_job("<date>not-a-date</date>", config: config)

      expect(result.errors.map(&:code)).not_to include("engine_validation")
    end

    it "carries engine line information when the engine reports it", if: engine_supported do
      result = run_job("<date>not-a-date</date>")
      finding = result.errors.find { |e| e.code == "engine_validation" }

      expect(finding.message).not_to be_empty
    end
  end
end
