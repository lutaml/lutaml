# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/validation/validation_configuration"

RSpec.describe Lutaml::Xsd::Validation::ValidationConfiguration do
  describe ".from_file" do
    context "with valid YAML file" do
      let(:config_file) { "spec/fixtures/valid_config.yml" }

      it "loads configuration from file" do
        # Create a temporary config file for testing
        require "fileutils"
        FileUtils.mkdir_p("spec/fixtures")
        File.write(config_file, {
          "validation" => {
            "strict_mode" => true,
            "max_errors" => 50,
          },
        }.to_yaml)

        config = described_class.from_file(config_file)
        expect(config).to be_a(described_class)
        expect(config.strict_mode?).to be true
        expect(config.max_errors).to eq(50)

        # Clean up
        FileUtils.rm_f(config_file)
      end
    end

    context "with non-existent file" do
      it "raises ConfigurationError" do
        expect do
          described_class.from_file("nonexistent.yml")
        end.to raise_error(
          Lutaml::Xsd::ConfigurationError,
          /Configuration file not found/,
        )
      end
    end

    context "with invalid YAML" do
      let(:invalid_yaml_file) { "spec/fixtures/invalid.yml" }

      it "raises ConfigurationError" do
        # Create a temporary invalid YAML file for testing
        require "fileutils"
        FileUtils.mkdir_p("spec/fixtures")
        File.write(invalid_yaml_file, "invalid: yaml: content: [")

        expect do
          described_class.from_file(invalid_yaml_file)
        end.to raise_error(
          Lutaml::Xsd::ConfigurationError,
          /Invalid YAML/,
        )

        # Clean up
        FileUtils.rm_f(invalid_yaml_file)
      end
    end
  end

  describe ".default" do
    it "returns default configuration" do
      config = described_class.default
      expect(config).to be_a(described_class)
    end

    it "has sensible default values" do
      config = described_class.default
      expect(config.strict_mode?).to be true
      expect(config.stop_on_first_error?).to be false
      expect(config.max_errors).to eq(100)
    end
  end

  describe "#initialize" do
    it "initializes with empty hash" do
      config = described_class.new({})
      expect(config).to be_a(described_class)
    end

    it "initializes with configuration hash" do
      hash = { "validation" => { "strict_mode" => false } }
      config = described_class.new(hash)
      expect(config).to be_a(described_class)
    end
  end

  describe "#strict_mode?" do
    it "returns true when strict_mode is enabled" do
      config = described_class.new(
        "validation" => { "strict_mode" => true },
      )
      expect(config.strict_mode?).to be true
    end

    it "returns false when strict_mode is disabled" do
      config = described_class.new(
        "validation" => { "strict_mode" => false },
      )
      expect(config.strict_mode?).to be false
    end

    it "returns false by default" do
      config = described_class.new({})
      expect(config.strict_mode?).to be false
    end
  end

  describe "#stop_on_first_error?" do
    it "returns configured value" do
      config = described_class.new(
        "validation" => { "stop_on_first_error" => true },
      )
      expect(config.stop_on_first_error?).to be true
    end

    it "returns false by default" do
      config = described_class.new({})
      expect(config.stop_on_first_error?).to be false
    end
  end

  describe "#max_errors" do
    it "returns configured value" do
      config = described_class.new(
        "validation" => { "max_errors" => 50 },
      )
      expect(config.max_errors).to eq(50)
    end

    it "returns 100 by default" do
      config = described_class.new({})
      expect(config.max_errors).to eq(100)
    end
  end

  describe "#feature_enabled?" do
    let(:config) do
      described_class.new(
        "validation" => {
          "features" => {
            "validate_types" => true,
            "validate_attributes" => false,
          },
        },
      )
    end

    it "returns true for enabled features" do
      expect(config.feature_enabled?(:validate_types)).to be true
    end

    it "returns false for disabled features" do
      expect(config.feature_enabled?(:validate_attributes)).to be false
    end

    it "returns true for undefined features (default enabled)" do
      expect(config.feature_enabled?(:unknown_feature)).to be true
    end
  end

  describe "#verbosity" do
    it "returns configured verbosity level" do
      config = described_class.new(
        "validation" => {
          "error_reporting" => { "verbosity" => "verbose" },
        },
      )
      expect(config.verbosity).to eq(:verbose)
    end

    it "returns :normal by default" do
      config = described_class.new({})
      expect(config.verbosity).to eq(:normal)
    end
  end

  describe "#colorize_output?" do
    it "returns configured value" do
      config = described_class.new(
        "validation" => {
          "error_reporting" => { "colorize" => false },
        },
      )
      expect(config.colorize_output?).to be false
    end

    it "returns true by default" do
      config = described_class.new({})
      expect(config.colorize_output?).to be true
    end
  end

  describe "#include_xpath?" do
    it "returns true by default" do
      config = described_class.new({})
      expect(config.include_xpath?).to be true
    end
  end

  describe "#include_line_number?" do
    it "returns true by default" do
      config = described_class.new({})
      expect(config.include_line_number?).to be true
    end
  end

  describe "#include_suggestions?" do
    it "returns true by default" do
      config = described_class.new({})
      expect(config.include_suggestions?).to be true
    end
  end

  describe "#allow_network?" do
    it "returns configured value" do
      config = described_class.new(
        "validation" => {
          "schema_resolution" => { "allow_network" => false },
        },
      )
      expect(config.allow_network?).to be false
    end

    it "returns true by default" do
      config = described_class.new({})
      expect(config.allow_network?).to be true
    end
  end

  describe "#cache_schemas?" do
    it "returns true by default" do
      config = described_class.new({})
      expect(config.cache_schemas?).to be true
    end
  end

  describe "#cache_dir" do
    it "returns configured cache directory" do
      config = described_class.new(
        "validation" => {
          "schema_resolution" => { "cache_dir" => "custom/cache" },
        },
      )
      expect(config.cache_dir).to eq("custom/cache")
    end

    it "returns default cache directory" do
      config = described_class.new({})
      expect(config.cache_dir).to eq("tmp/schema_cache")
    end
  end

  describe "#network_timeout" do
    it "returns configured timeout" do
      config = described_class.new(
        "validation" => {
          "schema_resolution" => { "network_timeout" => 60 },
        },
      )
      expect(config.network_timeout).to eq(60)
    end

    it "returns 30 seconds by default" do
      config = described_class.new({})
      expect(config.network_timeout).to eq(30)
    end
  end

  describe "#to_h" do
    it "returns configuration as hash" do
      hash = { "validation" => { "strict_mode" => true } }
      config = described_class.new(hash)
      expect(config.to_h).to eq(hash)
    end

    it "returns independent copy" do
      hash = { "validation" => { "strict_mode" => true } }
      config = described_class.new(hash)
      result = config.to_h
      result["validation"]["strict_mode"] = false
      expect(config.strict_mode?).to be true
    end
  end
end
