# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lutaml/model_transformations/configuration"
require "tempfile"

RSpec.describe Lutaml::ModelTransformations::Configuration do
  let(:sample_config_yaml) do
    <<~YAML
      version: "1.0"
      description: "Test Configuration"
      parsers:
        - format: "xmi"
          extension: ".xmi"
          parser_class: "TestXmiParser"
          enabled: true
          priority: 100
          description: "Test XMI parser"
          options:
            - "validate_xml"
        - format: "qea"
          extension: ".qea"
          parser_class: "TestQeaParser"
          enabled: false
          priority: 90
          description: "Test QEA parser"
          options:
            - "include_diagrams"
      transformation_options:
        validate_output: true
        include_diagrams: false
        preserve_ids: true
        resolve_references: true
        strict_mode: false
      format_detection:
        use_file_extension: true
        use_content_sniffing: false
        fallback_parser: "TestFallbackParser"
        magic_bytes:
          - "SQLite format 3"
      error_handling:
        strategy: "continue"
        log_errors: true
        max_errors: 5
        fail_fast: false
    YAML
  end

  describe ".load" do
    context "with valid configuration file" do
      let(:config_file) do
        file = Tempfile.new(["config", ".yml"])
        file.write(sample_config_yaml)
        file.close
        file
      end

      after { config_file.unlink }

      it "loads configuration from YAML file" do
        config = described_class.load(config_file.path)

        expect(config.version).to eq("1.0")
        expect(config.description).to eq("Test Configuration")
        expect(config.parsers.size).to eq(2)
      end

      it "parses parser configurations correctly" do
        config = described_class.load(config_file.path)

        xmi_parser = config.parser_config_for("xmi")
        expect(xmi_parser.format).to eq("xmi")
        expect(xmi_parser.extension).to eq(".xmi")
        expect(xmi_parser.parser_class).to eq("TestXmiParser")
        expect(xmi_parser.enabled).to be true
        expect(xmi_parser.priority).to eq(100)
      end

      it "parses transformation options correctly" do
        config = described_class.load(config_file.path)

        options = config.transformation_options
        expect(options.validate_output).to be true
        expect(options.include_diagrams).to be false
        expect(options.preserve_ids).to be true
      end

      it "parses format detection settings correctly" do
        config = described_class.load(config_file.path)

        detection = config.format_detection
        expect(detection.use_file_extension).to be true
        expect(detection.use_content_sniffing).to be false
        expect(detection.fallback_parser).to eq("TestFallbackParser")
      end

      it "parses error handling settings correctly" do
        config = described_class.load(config_file.path)

        error_handling = config.error_handling
        expect(error_handling.strategy).to eq("continue")
        expect(error_handling.log_errors).to be true
        expect(error_handling.max_errors).to eq(5)
        expect(error_handling.fail_fast).to be false
      end
    end

    context "with missing configuration file" do
      it "creates default configuration" do
        config = described_class.load("nonexistent.yml")

        expect(config.version).to eq("1.0")
        expect(config.description)
          .to eq("Default Model Transformations Configuration")
        expect(config.parsers.size).to be >= 2 # Should have XMI and QEA parsers
      end
    end

    context "with invalid YAML" do
      let(:invalid_config_file) do
        file = Tempfile.new(["invalid", ".yml"])
        file.write("invalid: yaml: content: [")
        file.close
        file
      end

      after { invalid_config_file.unlink }

      it "raises an error for invalid YAML" do
        expect do
          described_class.load(invalid_config_file.path)
        end.to raise_error(Lutaml::Model::InvalidFormatError)
      end
    end
  end

  describe ".create_default_configuration" do
    let(:config) { described_class.create_default_configuration }

    it "creates valid default configuration" do
      expect(config.version).to eq("1.0")
      expect(config.parsers.size).to eq(2)
      expect(config.transformation_options)
        .to be_a(described_class::TransformationOptions)
      expect(config.format_detection).to be_a(described_class::FormatDetection)
      expect(config.error_handling).to be_a(described_class::ErrorHandling)
    end

    it "includes XMI parser configuration" do
      xmi_parser = config.parser_config_for("xmi")
      expect(xmi_parser).not_to be_nil
      expect(xmi_parser.format).to eq("xmi")
      expect(xmi_parser.extension).to eq(".xmi")
      expect(xmi_parser.enabled).to be true
    end

    it "includes QEA parser configuration" do
      qea_parser = config.parser_config_for("qea")
      expect(qea_parser).not_to be_nil
      expect(qea_parser.format).to eq("qea")
      expect(qea_parser.extension).to eq(".qea")
      expect(qea_parser.enabled).to be true
    end
  end

  describe "#enabled_parsers" do
    let(:config) { described_class.from_yaml(sample_config_yaml) }

    it "returns only enabled parsers" do
      enabled = config.enabled_parsers
      expect(enabled.size).to eq(1)
      expect(enabled.first.format).to eq("xmi")
    end

    it "sorts parsers by priority (highest first)" do
      # Add another enabled parser with higher priority
      high_priority_yaml = sample_config_yaml
        .gsub("enabled: false", "enabled: true")
        .gsub("priority: 90", "priority: 150")

      config = described_class.from_yaml(high_priority_yaml)
      enabled = config.enabled_parsers

      expect(enabled.size).to eq(2)
      expect(enabled.first.priority).to be > enabled.last.priority
    end
  end

  describe "#parser_config_for" do
    let(:config) { described_class.from_yaml(sample_config_yaml) }

    it "finds parser by format name" do
      parser = config.parser_config_for("xmi")
      expect(parser.format).to eq("xmi")
    end

    it "returns nil for unknown format" do
      parser = config.parser_config_for("unknown")
      expect(parser).to be_nil
    end

    it "handles case insensitive lookup" do
      parser = config.parser_config_for("XMI")
      expect(parser.format).to eq("xmi")
    end
  end

  describe "#parser_config_for_extension" do
    let(:config) { described_class.from_yaml(sample_config_yaml) }

    it "finds parser by file extension" do
      parser = config.parser_config_for_extension(".xmi")
      expect(parser.format).to eq("xmi")
    end

    it "handles extension without leading dot" do
      parser = config.parser_config_for_extension("xmi")
      expect(parser.format).to eq("xmi")
    end

    it "handles case insensitive lookup" do
      parser = config.parser_config_for_extension(".XMI")
      expect(parser.format).to eq("xmi")
    end

    it "returns nil for unknown extension" do
      parser = config.parser_config_for_extension(".unknown")
      expect(parser).to be_nil
    end

    it "only returns enabled parsers" do
      parser = config.parser_config_for_extension(".qea")
      expect(parser).to be_nil # QEA parser is disabled in test config
    end
  end

  describe "#format_enabled?" do
    let(:config) { described_class.from_yaml(sample_config_yaml) }

    it "returns true for enabled formats" do
      expect(config.format_enabled?("xmi")).to be true
    end

    it "returns false for disabled formats" do
      expect(config.format_enabled?("qea")).to be false
    end

    it "returns false for unknown formats" do
      expect(config.format_enabled?("unknown")).to be false
    end
  end

  describe "#enabled_formats" do
    let(:config) { described_class.from_yaml(sample_config_yaml) }

    it "returns list of enabled format names" do
      formats = config.enabled_formats
      expect(formats).to eq(["xmi"])
    end
  end

  describe "#supported_extensions" do
    let(:config) { described_class.from_yaml(sample_config_yaml) }

    it "returns list of supported extensions" do
      extensions = config.supported_extensions
      expect(extensions).to eq([".xmi"])
    end
  end

  describe "#merge" do
    let(:base_config) { described_class.from_yaml(sample_config_yaml) }
    let(:other_config_yaml) do
      <<~YAML
        version: "2.0"
        parsers:
          - format: "custom"
            extension: ".custom"
            parser_class: "CustomParser"
            enabled: true
            priority: 80
      YAML
    end
    let(:other_config) { described_class.from_yaml(other_config_yaml) }

    it "merges configurations with precedence" do
      merged = base_config.merge(other_config)

      expect(merged.version).to eq("1.0") # base takes precedence
      expect(merged.parsers.size).to eq(3) # Should have all parsers

      # Check that custom parser was added
      custom_parser = merged.parser_config_for("custom")
      expect(custom_parser).not_to be_nil
      expect(custom_parser.format).to eq("custom")
    end
  end

  describe "ParserConfig" do
    describe "#handles_extension?" do
      let(:parser_config) do
        described_class::ParserConfig.new.tap do |config|
          config.extension = ".xmi"
        end
      end

      it "returns true for matching extension" do
        expect(parser_config.handles_extension?(".xmi")).to be true
      end

      it "handles case insensitive matching" do
        expect(parser_config.handles_extension?(".XMI")).to be true
      end

      it "returns false for non-matching extension" do
        expect(parser_config.handles_extension?(".qea")).to be false
      end
    end
  end

  describe "default options integration" do
    let(:config) { described_class.create_default_configuration }

    it "provides sensible defaults for transformation options" do
      options = config.transformation_options
      expect(options.validate_output)
        .to be false # Don't validate by default for performance
      expect(options.include_diagrams)
        .to be true # Include diagrams by default
      expect(options.preserve_ids)
        .to be true # Preserve IDs for reference integrity
      expect(options.resolve_references)
        .to be true # Resolve references by default
      expect(options.strict_mode)
        .to be false # Don't use strict mode by default
    end

    it "provides sensible defaults for format detection" do
      detection = config.format_detection
      expect(detection.use_file_extension)
        .to be true # Use extension-based detection
      expect(detection.use_content_sniffing)
        .to be true # Use content detection as fallback
    end

    it "provides sensible defaults for error handling" do
      error_handling = config.error_handling
      expect(error_handling.strategy)
        .to eq("continue") # Continue on errors by default
      expect(error_handling.log_errors)
        .to be true       # Log errors by default
      expect(error_handling.max_errors)
        .to eq(10)        # Reasonable error limit
      expect(error_handling.fail_fast)
        .to be false # Don't fail fast by default
    end
  end
end
