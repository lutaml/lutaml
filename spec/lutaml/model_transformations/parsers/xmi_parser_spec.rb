# frozen_string_literal: true

require "spec_helper"
require "lutaml/model_transformations/parsers/xmi_parser"
require "lutaml/model_transformations/configuration"
require "tempfile"

RSpec.describe Lutaml::ModelTransformations::Parsers::XmiParser do
  let(:configuration) { Lutaml::ModelTransformations::Configuration.new }
  let(:options) { {} }
  let(:parser) { described_class.new(configuration: configuration, options: options) }

  describe "#format_name" do
    it "returns XMI format name" do
      expect(parser.format_name).to eq("XMI (XML Metadata Interchange)")
    end
  end

  describe "#supported_extensions" do
    it "returns XMI file extensions" do
      extensions = parser.supported_extensions
      expect(extensions).to include(".xmi", ".xml", ".uml")
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
      expect(parser.priority).to eq(90)
    end
  end

  describe "#parse" do
    context "with valid XMI content" do
      let(:xmi_content) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <xmi:XMI xmi:version="2.0" xmlns:xmi="http://www.omg.org/XMI">
            <packagedElement xmi:type="uml:Package" xmi:id="pkg1" name="TestPackage">
              <packagedElement xmi:type="uml:Class" xmi:id="class1" name="TestClass">
                <ownedAttribute xmi:id="attr1" name="testAttribute" type="string"/>
              </packagedElement>
            </packagedElement>
          </xmi:XMI>
        XML
      end

      let(:xmi_file) do
        file = Tempfile.new(["test", ".xmi"])
        file.write(xmi_content)
        file.close
        file
      end

      after { xmi_file.unlink }

      it "successfully parses XMI file" do
        result = parser.parse(xmi_file.path)
        expect(result).to be_a(Lutaml::Uml::Document)
      end

      it "extracts packages from XMI" do
        result = parser.parse(xmi_file.path)
        expect(result.packages).not_to be_empty

        package = result.packages.first
        expect(package.name).to eq("TestPackage")
      end

      it "extracts classes from packages" do
        result = parser.parse(xmi_file.path)
        package = result.packages.first
        expect(package.classes).not_to be_empty

        klass = package.classes.first
        expect(klass.name).to eq("TestClass")
      end

      it "extracts attributes from classes" do
        result = parser.parse(xmi_file.path)
        package = result.packages.first
        klass = package.classes.first
        expect(klass.attributes).not_to be_empty

        attribute = klass.attributes.first
        expect(attribute.name).to eq("testAttribute")
      end

      it "records successful parsing statistics" do
        parser.parse(xmi_file.path)

        stats = parser.statistics
        expect(stats[:successful_parses]).to eq(1)
        expect(stats[:failed_parses]).to eq(0)
      end

      it "measures parsing duration" do
        parser.parse(xmi_file.path)
        expect(parser.last_duration).to be > 0
      end
    end

    context "with minimal valid XMI" do
      let(:minimal_xmi) do
        <<~XML
          <?xml version="1.0"?>
          <xmi:XMI xmi:version="2.0" xmlns:xmi="http://www.omg.org/XMI">
          </xmi:XMI>
        XML
      end

      let(:minimal_file) do
        file = Tempfile.new(["minimal", ".xmi"])
        file.write(minimal_xmi)
        file.close
        file
      end

      after { minimal_file.unlink }

      it "parses minimal XMI without errors" do
        result = parser.parse(minimal_file.path)
        expect(result).to be_a(Lutaml::Uml::Document)
        expect(result.packages).to be_empty
      end
    end

    context "with complex XMI structure" do
      let(:complex_xmi) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <xmi:XMI xmi:version="2.0" xmlns:xmi="http://www.omg.org/XMI" xmlns:uml="http://www.eclipse.org/uml2/3.0.0/UML">
            <packagedElement xmi:type="uml:Package" xmi:id="pkg1" name="RootPackage">
              <packagedElement xmi:type="uml:Package" xmi:id="pkg2" name="SubPackage">
                <packagedElement xmi:type="uml:Class" xmi:id="class1" name="BaseClass">
                  <ownedAttribute xmi:id="attr1" name="id" type="string"/>
                  <ownedOperation xmi:id="op1" name="getId" type="string"/>
                </packagedElement>
                <packagedElement xmi:type="uml:Class" xmi:id="class2" name="DerivedClass">
                  <generalization xmi:id="gen1" general="class1"/>
                  <ownedAttribute xmi:id="attr2" name="additionalData" type="string"/>
                </packagedElement>
              </packagedElement>
              <packagedElement xmi:type="uml:Association" xmi:id="assoc1" name="TestAssociation">
                <memberEnd xmi:idref="end1"/>
                <memberEnd xmi:idref="end2"/>
              </packagedElement>
            </packagedElement>
          </xmi:XMI>
        XML
      end

      let(:complex_file) do
        file = Tempfile.new(["complex", ".xmi"])
        file.write(complex_xmi)
        file.close
        file
      end

      after { complex_file.unlink }

      it "handles nested package structure" do
        result = parser.parse(complex_file.path)
        expect(result.packages).not_to be_empty

        root_package = result.packages.find { |p| p.name == "RootPackage" }
        expect(root_package).not_to be_nil
        expect(root_package.packages).not_to be_empty

        sub_package = root_package.packages.find { |p| p.name == "SubPackage" }
        expect(sub_package).not_to be_nil
      end

      it "extracts inheritance relationships" do
        result = parser.parse(complex_file.path)
        root_package = result.packages.find { |p| p.name == "RootPackage" }
        sub_package = root_package.packages.find { |p| p.name == "SubPackage" }

        derived_class = sub_package.classes.find { |c| c.name == "DerivedClass" }
        expect(derived_class).not_to be_nil
        expect(derived_class.generalizations).not_to be_empty
      end

      it "extracts associations" do
        result = parser.parse(complex_file.path)
        expect(result.associations).not_to be_empty

        association = result.associations.find { |a| a.name == "TestAssociation" }
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

      it "records failed parsing in statistics" do
        begin
          parser.parse(invalid_file.path)
        rescue StandardError
          # Expected error
        end

        stats = parser.statistics
        expect(stats[:failed_parses]).to eq(1)
        expect(stats[:successful_parses]).to eq(0)
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

      it "attempts to parse but may return empty document" do
        result = parser.parse(non_xmi_file.path)
        expect(result).to be_a(Lutaml::Uml::Document)
        # May have empty packages or handle gracefully
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
        end.to raise_error(ArgumentError, /File path cannot be nil or empty/)
      end

      it "raises error for empty file path" do
        expect do
          parser.parse("")
        end.to raise_error(ArgumentError, /File path cannot be nil or empty/)
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

      it "returns true for .uml files" do
        expect(parser.can_parse?("test.uml")).to be true
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

      let(:valid_xmi_file) do
        file = Tempfile.new(["valid", ".xmi"])
        file.write('<?xml version="1.0"?><xmi:XMI xmi:version="2.0" xmlns:xmi="http://www.omg.org/XMI"></xmi:XMI>')
        file.close
        file
      end

      let(:invalid_file) do
        file = Tempfile.new(["invalid", ".xmi"])
        file.write("Not valid XML content")
        file.close
        file
      end

      after do
        valid_xmi_file.unlink
        invalid_file.unlink
      end

      it "validates XMI file structure" do
        expect do
          parser.parse(valid_xmi_file.path)
        end.not_to raise_error
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

      let(:valid_xmi_file) do
        file = Tempfile.new(["valid", ".xmi"])
        file.write(<<~XML)
          <?xml version="1.0"?>
          <xmi:XMI xmi:version="2.0" xmlns:xmi="http://www.omg.org/XMI">
            <packagedElement xmi:type="uml:Package" name="TestPackage"/>
          </xmi:XMI>
        XML
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
        end
      ]

      expect(parser.configuration.parsers).not_to be_empty
    end

    it "uses transformation options from configuration" do
      configuration.transformation_options = Lutaml::ModelTransformations::Configuration::TransformationOptions.new
      configuration.transformation_options.preserve_ids = true

      # Parser should have access to these options through configuration
      expect(parser.configuration.transformation_options.preserve_ids).to be true
    end
  end

  describe "error handling" do
    let(:large_xmi_content) do
      # Generate large XMI content
      content = '<?xml version="1.0"?><xmi:XMI xmi:version="2.0" xmlns:xmi="http://www.omg.org/XMI">'
      1000.times do |i|
        content += %Q(<packagedElement xmi:type="uml:Class" name="Class#{i}"/>)
      end
      content += '</xmi:XMI>'
      content
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
      expect(result.classes.size).to eq(1000)
    end

    it "respects memory limits from options" do
      parser_with_limits = described_class.new(
        configuration: configuration,
        options: { memory_limit: 1 } # Very low limit
      )

      # Should still parse but may take longer or use different strategy
      result = parser_with_limits.parse(large_file.path)
      expect(result).to be_a(Lutaml::Uml::Document)
    end
  end

  describe "performance characteristics" do
    let(:performance_xmi) do
      # Create XMI with moderate complexity for performance testing
      content = <<~XML
        <?xml version="1.0"?>
        <xmi:XMI xmi:version="2.0" xmlns:xmi="http://www.omg.org/XMI">
      XML

      50.times do |i|
        content += <<~XML
          <packagedElement xmi:type="uml:Package" name="Package#{i}">
            <packagedElement xmi:type="uml:Class" name="Class#{i}A">
              <ownedAttribute name="attr#{i}A1" type="string"/>
              <ownedAttribute name="attr#{i}A2" type="integer"/>
            </packagedElement>
            <packagedElement xmi:type="uml:Class" name="Class#{i}B">
              <ownedAttribute name="attr#{i}B1" type="boolean"/>
            </packagedElement>
          </packagedElement>
        XML
      end

      content += "</xmi:XMI>"
      content
    end

    let(:performance_file) do
      file = Tempfile.new(["performance", ".xmi"])
      file.write(performance_xmi)
      file.close
      file
    end

    after { performance_file.unlink }

    it "parses moderate-complexity XMI in reasonable time" do
      start_time = Time.now
      result = parser.parse(performance_file.path)
      duration = Time.now - start_time

      expect(result).to be_a(Lutaml::Uml::Document)
      expect(duration).to be < 5.0  # Should parse in under 5 seconds
      expect(result.packages.size).to eq(50)
    end

    it "provides accurate timing statistics" do
      parser.parse(performance_file.path)

      stats = parser.statistics
      expect(stats[:average_duration]).to be > 0
      expect(stats[:total_duration]).to be >= stats[:average_duration]
    end
  end
end