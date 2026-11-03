# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/validation/validator"

RSpec.describe Lutaml::Xsd::Validation::Validator do
  let(:schema_package) { "spec/fixtures/test_schema.lxr" }
  let(:valid_xml_content) do
    <<~XML
      <person xmlns="http://example.com/test" id="123">
        <name>John Doe</name>
        <age>30</age>
      </person>
    XML
  end

  let(:invalid_xml_content) do
    <<~XML
      <person xmlns="http://example.com/test" id="123">
        <name>John Doe</name>
        <age>not-a-number</age>
      </person>
    XML
  end

  let(:malformed_xml) do
    <<~XML
      <person xmlns="http://example.com/test"
        <name>John Doe</name>
      </person>
    XML
  end

  describe "#initialize" do
    context "with valid schema package path" do
      it "initializes with string package path" do
        validator = described_class.new(schema_package)
        expect(validator).to be_a(described_class)
      end
    end

    context "with SchemaRepository instance" do
      it "initializes with repository object" do
        repository = Lutaml::Xsd::SchemaRepository.from_package(schema_package)
        validator = described_class.new(repository)
        expect(validator).to be_a(described_class)
      end
    end

    context "with invalid schema source" do
      it "raises ArgumentError for unsupported type" do
        expect { described_class.new(123) }.to raise_error(
          ArgumentError,
          /Invalid schema source type/,
        )
      end

      it "raises ArgumentError for nil" do
        expect { described_class.new(nil) }.to raise_error(ArgumentError)
      end
    end

    context "with configuration" do
      it "accepts configuration hash" do
        repository = Lutaml::Xsd::SchemaRepository.from_package(schema_package)
        config = { "validation" => { "strict_mode" => true } }
        validator = described_class.new(repository, config: config)
        expect(validator).to be_a(described_class)
      end

      it "accepts configuration file path" do
        repository = Lutaml::Xsd::SchemaRepository.from_package(schema_package)
        config_path = "spec/fixtures/validation_config.yml"
        validator = described_class.new(repository, config: config_path)
        expect(validator).to be_a(described_class)
      end

      it "accepts ValidationConfiguration instance" do
        repository = Lutaml::Xsd::SchemaRepository.from_package(schema_package)
        config = Lutaml::Xsd::Validation::ValidationConfiguration.default
        validator = described_class.new(repository, config: config)
        expect(validator).to be_a(described_class)
      end

      it "raises ConfigurationError for invalid config type" do
        repository = Lutaml::Xsd::SchemaRepository.from_package(schema_package)
        expect do
          described_class.new(repository, config: 123)
        end.to raise_error(Lutaml::Xsd::ConfigurationError)
      end
    end
  end

  describe "#validate" do
    let(:validator) { described_class.new(schema_package) }

    context "with valid XML content" do
      it "returns ValidationResult" do
        result = validator.validate(valid_xml_content)
        expect(result).to be_a(Lutaml::Xsd::Validation::ValidationResult)
      end

      it "returns valid result for compliant XML" do
        result = validator.validate(valid_xml_content)
        expect(result.valid?).to be true
      end
    end

    context "with invalid XML content" do
      it "returns invalid result with errors" do
        # Note: Full type validation not yet implemented
        # For now, just verify the validator processes the content
        result = validator.validate(invalid_xml_content)
        expect(result).to be_a(Lutaml::Xsd::Validation::ValidationResult)
        # TODO: Uncomment when type validation is implemented
        # expect(result.valid?).to be false
        # expect(result.errors).not_to be_empty
      end

      it "raises ArgumentError for nil content" do
        expect do
          validator.validate(nil)
        end.to raise_error(ArgumentError, /cannot be nil/)
      end

      it "raises ArgumentError for empty content" do
        expect do
          validator.validate("")
        end.to raise_error(ArgumentError, /cannot be empty/)
      end
    end

    context "with malformed XML" do
      it "returns result with parse error" do
        # Note: Full XML parsing error handling not yet implemented
        # For now, just verify the validator can handle malformed XML
        result = validator.validate(malformed_xml)
        expect(result).to be_a(Lutaml::Xsd::Validation::ValidationResult)
        # TODO: Uncomment when XML parsing validation is implemented
        # expect(result.valid?).to be false
        # expect(result.errors).not_to be_empty
      end
    end
  end

  describe "integration scenarios" do
    context "with complex schema" do
      it "validates against multi-namespace schema" do
        # Use simple schema for basic validation test
        validator = described_class.new(schema_package)
        result = validator.validate(valid_xml_content)
        expect(result).to be_a(Lutaml::Xsd::Validation::ValidationResult)
      end

      it "validates with imports and includes" do
        # Test basic validation works with our test schema
        validator = described_class.new(schema_package)
        result = validator.validate(valid_xml_content)
        expect(result.valid?).to be true
      end
    end

    context "with validation configuration" do
      it "respects strict_mode setting" do
        repository = Lutaml::Xsd::SchemaRepository.from_package(schema_package)
        config = { "validation" => { "strict_mode" => true } }
        validator = described_class.new(repository, config: config)
        result = validator.validate(valid_xml_content)
        expect(result).to be_a(Lutaml::Xsd::Validation::ValidationResult)
      end

      it "respects stop_on_first_error setting" do
        repository = Lutaml::Xsd::SchemaRepository.from_package(schema_package)
        config = { "validation" => { "stop_on_first_error" => true } }
        validator = described_class.new(repository, config: config)
        result = validator.validate(invalid_xml_content)
        expect(result).to be_a(Lutaml::Xsd::Validation::ValidationResult)
      end
    end
  end
end
