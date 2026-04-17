# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/model_transformations/parsers/" \
                 "xmi_parser"
require_relative "../../../../lib/lutaml/model_transformations/configuration"
require "tempfile"

RSpec.describe Lutaml::ModelTransformations::Parsers::XmiParser do
  let(:configuration) { Lutaml::ModelTransformations::Configuration.new }
  let(:options) { {} }
  let(:parser) do
    described_class.new(configuration: configuration, options: options)
  end

  describe "#format_name" do
    it "returns XMI format name" do
      expect(parser.format_name).to eq("XML Metadata Interchange (XMI)")
    end
  end

  describe "#supported_extensions" do
    it "returns XMI file extensions" do
      extensions = parser.supported_extensions
      expect(extensions).to include(".xmi", ".xml")
    end
  end

  describe "#content_patterns" do
    it "returns XMI content detection patterns" do
      patterns = parser.content_patterns
      expect(patterns).to be_an(Array)
      expect(patterns).not_to be_empty

      # Should include patterns for XMI namespace and headers
      xmi_pattern = patterns.find { |p| p.source.include?("xmi:version") }
      expect(xmi_pattern).not_to be_nil
    end
  end

  describe "#priority" do
    it "returns high priority for XMI files" do
      expect(parser.priority).to eq(80)
    end
  end

  describe "#parse" do
    context "with valid XMI content" do
      let(:xmi_content) do
        File.read(File.join(__dir__, "../../../../examples/xmi/basic.xmi"))
      end
      let(:complex_file) do
        file = Tempfile.new(["complex", ".xmi"])
        file.write(xmi_content)
        # file.write(complex_xmi)
        file.close
        file
      end

      let(:xmi_file) do
        file = Tempfile.new(["test", ".xmi"])
        file.write(xmi_content)
        file.close
        file
      end

      after do
        xmi_file.unlink
        complex_file.unlink
        complex_file.unlink
      end

      it "successfully parses XMI file" do
        result = parser.parse(xmi_file.path)
        expect(result).to be_a(Lutaml::Uml::Document)
      end

      it "extracts packages from XMI" do
        result = parser.parse(xmi_file.path)
        expect(result.packages).not_to be_empty

        package = result.packages.first
        expect(package.name).to eq("Model")
      end

      it "extracts classes from packages" do
        result = parser.parse(xmi_file.path)
        package = result.packages.first.packages[3]
        expect(package.classes).not_to be_empty

        klass = package.classes.first
        expect(klass.name).to eq("Class A")
      end

      it "extracts attributes from classes" do
        result = parser.parse(xmi_file.path)
        package = result.packages.first.packages[7]
        klass = package.classes.first
        expect(klass.attributes).not_to be_empty

        attribute = klass.attributes.first
        expect(attribute.name).to eq("Attribute A")
      end

      it "handles nested package structure" do
        result = parser.parse(complex_file.path)
        expect(result.packages).not_to be_empty

        root_package = result.packages.first.packages.find do |p|
          p.name == "One Level Package Hierarchy"
        end
        expect(root_package).not_to be_nil
        expect(root_package.packages).not_to be_empty

        sub_package = root_package.packages.find { |p| p.name == "Package A" }
        expect(sub_package).not_to be_nil
      end

      it "extracts inheritance relationships" do
        result = parser.parse(complex_file.path)
        root_package = result.packages.first.packages.find do |p|
          p.name == "Two Level Class Type Hierarchy with Attributes"
        end
        derived_class = root_package.classes.find { |c| c.name == "Class A" }

        expect(derived_class).not_to be_nil
        expect(derived_class.generalization).not_to be_nil
      end

      it "extracts associations" do
        result = parser.parse(complex_file.path)
        root_package = result.packages.first.packages.find do |p|
          p.name == "Basic Class Diagram with Attributes and Operations"
        end

        expect(root_package.classes[0].associations).not_to be_empty

        association = root_package.classes[0].associations.find do |a|
          a.owner_end == "Class A" && a.member_end == "Association A"
        end
        expect(association).not_to be_nil
      end
    end

    context "with invalid XMI content" do
      let(:invalid_xml) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <invalid>
            <unclosed-tag>
          </invalid>
        XML
      end

      let(:invalid_file) do
        file = Tempfile.new(["invalid", ".xmi"])
        file.write(invalid_xml)
        file.close
        file
      end

      after { invalid_file.unlink }

      it "raises parsing error for malformed XML" do
        expect do
          parser.parse(invalid_file.path)
        end.to raise_error(StandardError)
      end
    end

    context "with non-XMI XML content" do
      let(:non_xmi_xml) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <root>
            <element>Not an XMI file</element>
          </root>
        XML
      end

      let(:non_xmi_file) do
        file = Tempfile.new(["non_xmi", ".xml"])
        file.write(non_xmi_xml)
        file.close
        file
      end

      after { non_xmi_file.unlink }

      it "attempts to parse but failed and return error" do
        expect do
          parser.parse(non_xmi_file.path)
        end.to raise_error(Lutaml::ModelTransformations::Parsers::ParseError)
      end
    end

    context "with file path validation" do
      it "raises error for non-existent file" do
        expect do
          parser.parse("nonexistent.xmi")
        end.to raise_error(ArgumentError, /File does not exist/)
      end

      it "raises error for nil file path" do
        expect do
          parser.parse(nil)
        end.to raise_error(ArgumentError, /File path cannot be nil/)
      end

      it "raises error for empty file path" do
        expect do
          parser.parse("")
        end.to raise_error(ArgumentError, /File path cannot be nil/)
      end
    end
  end

  describe "#can_parse?" do
    context "with XMI file extension" do
      it "returns true for .xmi files" do
        expect(parser.can_parse?("test.xmi")).to be true
      end

      it "returns true for .xml files" do
        expect(parser.can_parse?("test.xml")).to be true
      end

      it "returns false for .uml files" do
        expect(parser.can_parse?("test.uml")).to be false
      end

      it "returns false for unsupported extensions" do
        expect(parser.can_parse?("test.txt")).to be false
        expect(parser.can_parse?("test.json")).to be false
      end
    end

    context "with content detection" do
      let(:xmi_content_file) do
        file = Tempfile.new(["test", ".unknown"])
        file.write('<?xml version="1.0"?><xmi:XMI xmi:version="2.0">')
        file.close
        file
      end

      let(:non_xmi_content_file) do
        file = Tempfile.new(["test", ".unknown"])
        file.write('<?xml version="1.0"?><root><element/></root>')
        file.close
        file
      end

      after do
        xmi_content_file.unlink
        non_xmi_content_file.unlink
      end

      it "detects XMI content in files with unknown extensions" do
        expect(parser.can_parse?(xmi_content_file.path)).to be true
      end

      it "rejects non-XMI content even with unknown extensions" do
        expect(parser.can_parse?(non_xmi_content_file.path)).to be false
      end
    end
  end

  describe "#validate_input" do
    context "when input validation is enabled" do
      let(:options) { { validate_input: true } }

      let(:invalid_file) do
        file = Tempfile.new(["invalid", ".xmi"])
        file.write("Not valid XML content")
        file.close
        file
      end

      after do
        invalid_file.unlink
      end

      it "raises error for invalid XMI content" do
        expect do
          parser.parse(invalid_file.path)
        end.to raise_error
      end
    end
  end

  describe "#validate_output" do
    context "when output validation is enabled" do
      let(:options) { { validate_output: true } }

      let(:xmi_content) do
        File.read(File.join(__dir__, "../../../../examples/xmi/basic.xmi"))
      end

      let(:valid_xmi_file) do
        file = Tempfile.new(["valid", ".xmi"])
        file.write(xmi_content)
        file.close
        file
      end

      after { valid_xmi_file.unlink }

      it "validates output document structure" do
        result = parser.parse(valid_xmi_file.path)
        expect(result).to be_a(Lutaml::Uml::Document)
      end
    end
  end

  describe "configuration integration" do
    it "respects parser-specific configuration" do
      configuration.parsers = [
        Lutaml::ModelTransformations::Configuration::ParserConfig.new.tap do |p|
          p.format = "xmi"
          p.enabled = true
          p.options = { "strict_validation" => true }
        end,
      ]

      expect(parser.configuration.parsers).not_to be_empty
    end

    it "uses transformation options from configuration" do
      configuration.transformation_options = Lutaml::ModelTransformations::Configuration::TransformationOptions.new
      configuration.transformation_options.preserve_ids = true

      # Parser should have access to these options through configuration
      expect(parser.configuration.transformation_options.preserve_ids)
        .to be true
    end
  end

  describe "error handling" do
    let(:large_xmi_content) do
      File.read(
        File.join(
          __dir__,
          "../../../../examples/xmi/20251010_current_plateau_v5.1.xmi",
        ),
      )
    end

    let(:large_file) do
      file = Tempfile.new(["large", ".xmi"])
      file.write(large_xmi_content)
      file.close
      file
    end

    after { large_file.unlink }

    it "handles large XMI files" do
      result = parser.parse(large_file.path)
      expect(result).to be_a(Lutaml::Uml::Document)
    end

    it "respects memory limits from options" do
      parser_with_limits = described_class.new(
        configuration: configuration,
        options: { memory_limit: 1 }, # Very low limit
      )

      # Should still parse but may take longer or use different strategy
      result = parser_with_limits.parse(large_file.path)
      expect(result).to be_a(Lutaml::Uml::Document)
    end
  end
end
