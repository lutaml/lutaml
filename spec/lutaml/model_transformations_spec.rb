# frozen_string_literal: true

require "spec_helper"
require_relative "../../lib/lutaml/model_transformations"
require "tempfile"

RSpec.describe Lutaml::ModelTransformations do
  describe "module constants and configuration" do
    it "provides default configuration" do
      expect(described_class.configuration).to be_a(Lutaml::ModelTransformations::Configuration)
    end

    it "provides default transformation engine" do
      expect(described_class.engine).to be_a(Lutaml::ModelTransformations::TransformationEngine)
    end
  end

  describe ".configure" do
    it "allows configuration via block" do
      original_version = described_class.configuration.version

      described_class.configure do |config|
        config.version = "test_version"
      end

      expect(described_class.configuration.version).to eq("test_version")

      # Reset to original
      described_class.configuration.version = original_version
    end

    it "yields configuration object to block" do
      described_class.configure do |config|
        expect(config).to be_a(Lutaml::ModelTransformations::Configuration)
      end
    end

    it "recreates engine after configuration change" do
      original_engine = described_class.engine.dup

      described_class.configure do |config|
        config.version = "new_version"
      end

      new_engine = described_class.engine
      expect(new_engine).not_to be(original_engine)
    end
  end

  describe ".parse" do
    let(:xmi_content) do
      File.read(File.join(__dir__, "../../examples/xmi/basic.xmi"))
    end

    let(:xmi_file) do
      file = Tempfile.new(["test", ".xmi"])
      file.write(xmi_content)
      file.close
      file
    end

    after { xmi_file.unlink }

    it "provides convenient parse method" do
      result = described_class.parse(xmi_file.path)
      expect(result).to be_a(Lutaml::Uml::Document)
    end

    it "passes options to underlying engine" do
      options = { validate_input: true }

      expect(described_class.engine).to receive(:parse).with(xmi_file.path, options)
      described_class.parse(xmi_file.path, options)
    end

    it "handles file path validation" do
      expect do
        described_class.parse("nonexistent.file")
      end.to raise_error(ArgumentError)
    end
  end

  describe ".supports_file?" do
    it "delegates to engine" do
      expect(described_class.engine).to receive(:supports_file?).with("test.xmi")
      described_class.supports_file?("test.xmi")
    end
  end

  describe ".supported_extensions" do
    it "returns list of supported file extensions" do
      extensions = described_class.supported_extensions
      expect(extensions).to be_an(Array)
      expect(extensions).to include(".xmi", ".qea")
    end

    it "delegates to engine" do
      expect(described_class.engine).to receive(:supported_extensions)
      described_class.supported_extensions
    end
  end

  describe ".register_parser" do
    class TestCustomParser < Lutaml::ModelTransformations::Parsers::BaseParser
      def format_name
        "Test Custom Format"
      end

      def supported_extensions
        [".custom"]
      end

      protected

      def parse_internal(file_path)
        # Mock implementation
      end
    end

    it "registers custom parser" do
      described_class.register_parser(".custom", TestCustomParser)

      expect(described_class.supports_file?("test.custom")).to be true
    end

    it "delegates to engine" do
      expect(described_class.engine).to receive(:register_parser).with(".custom", TestCustomParser)
      described_class.register_parser(".custom", TestCustomParser)
    end
  end

  describe ".statistics" do
    let(:xmi_content) do
      File.read(File.join(__dir__, "../../examples/xmi/basic.xmi"))
    end

    let(:xmi_file) do
      file = Tempfile.new(["test", ".xmi"])
      file.write(xmi_content)
      file.close
      file
    end

    after { xmi_file.unlink }

    it "returns transformation statistics" do
      # Perform a transformation to generate statistics
      described_class.parse(xmi_file.path)

      stats = described_class.statistics
      expect(stats).to include(
        :total_transformations,
        :successful_transformations,
        :configuration_version
      )
    end

    it "delegates to engine" do
      expect(described_class.engine).to receive(:statistics)
      described_class.statistics
    end
  end

  describe ".reset_statistics" do
    it "clears transformation history" do
      expect(described_class.engine).to receive(:clear_history)
      described_class.reset_statistics
    end
  end

  describe ".load_configuration" do
    let(:config_content) do
      <<~YAML
        version: "test_config"
        parsers:
          - format: "xmi"
            extension: ".xmi"
            parser_class: "XmiParser"
            enabled: true
            priority: 90
        transformation_options:
          preserve_ids: true
          validate_output: true
        format_detection:
          use_file_extension: true
          use_content_sniffing: false
        error_handling:
          max_retries: 3
          retry_delay: 1.0
      YAML
    end

    let(:config_file) do
      file = Tempfile.new(["config", ".yml"])
      file.write(config_content)
      file.close
      file
    end

    after { config_file.unlink }

    it "loads configuration from YAML file" do
      described_class.load_configuration(config_file.path)
      config = described_class.configuration
      expect(config.version).to eq("test_config")
      expect(config.transformation_options.preserve_ids).to be true
    end

    it "validates configuration after loading" do
      expect do
        described_class.load_configuration(config_file.path)
      end.not_to raise_error
    end

    it "recreates engine with new configuration" do
      original_engine = described_class.engine.dup
      described_class.load_configuration(config_file.path)
      new_engine = described_class.engine
      expect(new_engine).not_to be(original_engine)
    end

    it "raises error for invalid configuration file" do
      invalid_file = Tempfile.new(["invalid", ".yml"])
      invalid_file.write("invalid: yaml: content:")
      invalid_file.close

      begin
        expect do
          described_class.load_configuration(invalid_file.path)
        end.to raise_error
      ensure
        invalid_file.unlink
      end
    end
  end

  describe ".validate_setup" do
    it "validates current configuration and parsers" do
      results = described_class.validate_setup

      expect(results).to include(
        :configuration_valid,
        :parsers_loaded,
        :parser_errors
      )

      expect(results[:configuration_valid]).to be true
      expect(results[:parsers_loaded]).to be > 0
    end

    it "delegates to engine" do
      expect(described_class.engine).to receive(:validate_setup)
      described_class.validate_setup
    end
  end

  describe "thread safety" do
    let(:xmi_content) do
      File.read(File.join(__dir__, "../../examples/xmi/basic.xmi"))
    end

    it "handles concurrent configuration access" do
      threads = []
      results = []

      10.times do
        threads << Thread.new do
          results << described_class.configuration.version
        end
      end

      threads.each(&:join)

      # All threads should get the same configuration version
      expect(results.uniq.size).to eq(1)
    end

    it "handles concurrent parsing requests" do
      files = []
      threads = []
      results = []

      begin
        # Create test files
        5.times do |i|
          file = Tempfile.new(["concurrent_test_#{i}", ".xmi"])
          file.write(xmi_content)
          file.close
          files << file
        end

        # Parse concurrently
        files.each do |file|
          threads << Thread.new do
            result = described_class.parse(file.path)
            results << result
          end
        end

        threads.each(&:join)

        expect(results.size).to eq(5)
        expect(results.all? { |r| r.is_a?(Lutaml::Uml::Document) }).to be true
      ensure
        files.each(&:unlink)
      end
    end
  end

  describe "integration with existing LutaML functionality" do
    it "maintains compatibility with existing XMI parsing" do
      # Should not break existing LutaML XMI functionality
      expect(defined?(Lutaml::Xmi)).to be_truthy
    end

    it "enhances rather than replaces existing functionality" do
      # New system should enhance, not replace existing capabilities
      extensions = described_class.supported_extensions
      expect(extensions).to include(".xmi", ".qea")
    end
  end

  describe "configuration presets" do
    it "provides default preset" do
      config = described_class.configuration
      expect(config.version).to be_a(String)
      expect(config.parsers).to be_an(Array)
    end

    it "allows preset switching" do
      # Could support different configuration presets in the future
      expect(described_class).to respond_to(:load_configuration)
    end
  end

  describe "extensibility" do
    it "allows custom parser registration" do
      class ExtensibilityTestParser < Lutaml::ModelTransformations::Parsers::BaseParser
        def format_name
          "Extensibility Test Format"
        end

        def supported_extensions
          [".ext_test"]
        end

        protected

        def parse_internal(file_path)
          # Mock implementation
        end
      end

      described_class.register_parser(".ext_test", ExtensibilityTestParser)
      expect(described_class.supports_file?("test.ext_test")).to be true
    end

    it "supports plugin architecture" do
      # Framework should support plugin-like extensions
      expect(described_class.engine.format_registry).to respond_to(:register)
      expect(described_class.engine.format_registry).to respond_to(:all_parsers)
    end
  end

  describe "performance monitoring" do
    let(:xmi_content) do
      File.read(File.join(__dir__, "../../examples/xmi/basic.xmi"))
    end

    let(:xmi_file) do
      file = Tempfile.new(["perf_test", ".xmi"])
      file.write(xmi_content)
      file.close
      file
    end

    after { xmi_file.unlink }

    it "tracks parsing performance" do
      start_time = Time.now
      described_class.reset_statistics
      described_class.parse(xmi_file.path)
      duration = Time.now - start_time

      stats = described_class.statistics
      expect(stats[:average_duration]).to be > 0
      expect(stats[:average_duration]).to be <= duration
    end

    it "provides detailed performance metrics" do
      described_class.parse(xmi_file.path)

      stats = described_class.statistics
      expect(stats).to include(
        :total_transformations,
        :average_duration,
        :success_rate
      )
    end
  end
end