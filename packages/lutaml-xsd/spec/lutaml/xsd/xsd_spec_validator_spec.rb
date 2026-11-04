# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/xsd_spec_validator"

RSpec.describe Lutaml::Xsd::XsdSpecValidator do
  let(:repository) { instance_double(Lutaml::Xsd::SchemaRepository) }

  describe "#initialize" do
    it "creates validator with default version 1.0" do
      validator = described_class.new(repository)
      expect(validator.version).to eq("1.0")
    end

    it "creates validator with specified version" do
      validator = described_class.new(repository, version: "1.1")
      expect(validator.version).to eq("1.1")
    end
  end

  describe "#validate" do
    let(:mock_schemas) do
      {
        "schema1.xsd" => double(
          target_namespace: "http://example.com/ns1",
          element_form_default: "qualified",
          attribute_form_default: "unqualified",
          import: [],
          include: [],
          complex_type: [],
          simple_type: [],
          element: [],
          attribute: [],
        ),
      }
    end

    before do
      allow(repository).to receive(:all_schemas)
        .and_return(mock_schemas)
    end

    it "returns SpecComplianceReport" do
      validator = described_class.new(repository)
      report = validator.validate

      expect(report).to be_a(Lutaml::Xsd::SpecComplianceReport)
      expect(report.version).to eq("1.0")
      expect(report.schemas_checked).to eq(1)
    end

    it "validates without errors for compliant schemas" do
      validator = described_class.new(repository)
      report = validator.validate

      expect(report.valid).to be true
      expect(report.errors).to be_empty
    end

    context "with missing target namespace" do
      let(:mock_schemas) do
        {
          "schema1.xsd" => double(
            target_namespace: nil,
            element_form_default: "qualified",
            attribute_form_default: "unqualified",
            import: [],
            include: [],
            complex_type: [],
            simple_type: [],
            element: [],
            attribute: [],
          ),
        }
      end

      it "reports warning for missing target namespace" do
        validator = described_class.new(repository)
        report = validator.validate

        expect(report.warnings).to include(
          match(/schema1\.xsd has no target namespace/),
        )
      end
    end

    context "with duplicate definitions" do
      let(:mock_schemas) do
        {
          "schema1.xsd" => double(
            target_namespace: "http://example.com/ns",
            element_form_default: "qualified",
            attribute_form_default: "unqualified",
            import: [],
            include: [],
            complex_type: [
              double(name: "MyType"),
            ],
            simple_type: [],
            element: [],
            attribute: [],
          ),
          "schema2.xsd" => double(
            target_namespace: "http://example.com/ns",
            element_form_default: "qualified",
            attribute_form_default: "unqualified",
            import: [],
            include: [],
            complex_type: [
              double(name: "MyType"),
            ],
            simple_type: [],
            element: [],
            attribute: [],
          ),
        }
      end

      it "reports error for duplicate type definitions" do
        validator = described_class.new(repository)
        report = validator.validate

        expect(report.valid).to be false
        expect(report.errors).to include(
          match(/Duplicate complexType 'MyType'/),
        )
      end
    end
  end
end

RSpec.describe Lutaml::Xsd::SpecComplianceReport do
  describe "#initialize" do
    it "creates report with all attributes" do
      report = described_class.new(
        version: "1.0",
        valid: true,
        errors: [],
        warnings: ["warning1"],
        schemas_checked: 5,
      )

      expect(report.version).to eq("1.0")
      expect(report.valid).to be true
      expect(report.errors).to eq([])
      expect(report.warnings).to eq(["warning1"])
      expect(report.schemas_checked).to eq(5)
    end
  end

  describe "#to_h" do
    it "converts to hash with all fields" do
      report = described_class.new(
        version: "1.0",
        valid: true,
        errors: ["error1"],
        warnings: ["warning1"],
        schemas_checked: 3,
      )

      hash = report.to_h

      expect(hash).to include(
        xsd_version: "1.0",
        valid: true,
        schemas_checked: 3,
        errors: ["error1"],
        warnings: ["warning1"],
        error_count: 1,
        warning_count: 1,
      )
    end
  end
end

RSpec.describe Lutaml::Xsd::TargetNamespaceRule do
  let(:rule) { described_class.new("1.0") }
  let(:repository) { instance_double(Lutaml::Xsd::SchemaRepository) }

  describe "#validate" do
    it "reports warning for schema without target namespace" do
      schemas = {
        "test.xsd" => double(target_namespace: nil),
      }
      allow(repository).to receive(:all_schemas)
        .and_return(schemas)

      result = rule.validate(repository)

      expect(result[:warnings]).to include(
        match(/test\.xsd has no target namespace/),
      )
    end

    it "reports warning for non-URI target namespace" do
      schemas = {
        "test.xsd" => double(target_namespace: "just-a-string"),
      }
      allow(repository).to receive(:all_schemas)
        .and_return(schemas)

      result = rule.validate(repository)

      expect(result[:warnings]).to include(
        match(/is not a URI/),
      )
    end

    it "passes for valid HTTP URI namespace" do
      schemas = {
        "test.xsd" => double(target_namespace: "http://example.com/ns"),
      }
      allow(repository).to receive(:all_schemas)
        .and_return(schemas)

      result = rule.validate(repository)

      expect(result[:warnings]).to be_empty
    end
  end
end

RSpec.describe Lutaml::Xsd::DuplicateDefinitionRule do
  let(:rule) { described_class.new("1.0") }
  let(:repository) { instance_double(Lutaml::Xsd::SchemaRepository) }

  describe "#validate" do
    it "detects duplicate complex types in same namespace" do
      schemas = {
        "schema1.xsd" => double(
          target_namespace: "http://example.com/ns",
          complex_type: [double(name: "MyType")],
          simple_type: [],
          element: [],
          attribute: [],
        ),
        "schema2.xsd" => double(
          target_namespace: "http://example.com/ns",
          complex_type: [double(name: "MyType")],
          simple_type: [],
          element: [],
          attribute: [],
        ),
      }
      allow(repository).to receive(:all_schemas)
        .and_return(schemas)

      result = rule.validate(repository)

      expect(result[:errors]).to include(
        match(/Duplicate complexType 'MyType'/),
      )
    end

    it "allows same name in different namespaces" do
      schemas = {
        "schema1.xsd" => double(
          target_namespace: "http://example.com/ns1",
          complex_type: [double(name: "MyType")],
          simple_type: [],
          element: [],
          attribute: [],
        ),
        "schema2.xsd" => double(
          target_namespace: "http://example.com/ns2",
          complex_type: [double(name: "MyType")],
          simple_type: [],
          element: [],
          attribute: [],
        ),
      }
      allow(repository).to receive(:all_schemas)
        .and_return(schemas)

      result = rule.validate(repository)

      expect(result[:errors]).to be_empty
    end
  end
end
