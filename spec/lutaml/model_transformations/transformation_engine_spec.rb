# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lutaml/model_transformations/transformation_engine"
require_relative "../../../lib/lutaml/model_transformations/configuration"
require_relative "../../../lib/lutaml/model_transformations/parsers/base_parser"
require "tempfile"

RSpec.describe Lutaml::ModelTransformations::TransformationEngine do
  # Mock parser for testing
  class MockParser < Lutaml::ModelTransformations::Parsers::BaseParser
    attr_reader :parse_called_with

    def format_name
      "Mock Format"
    end

    def supported_extensions
      [".mock"]
    end

    protected

    def parse_internal(file_path)
      @parse_called_with = file_path

      # Create a mock UML document
      doc = double("Lutaml::Uml::Document")
      allow(doc).to receive(:packages).and_return([])
      allow(doc).to receive(:classes).and_return([])
      allow(doc).to receive(:is_a?).with(Lutaml::Uml::Document).and_return(true)
      doc
    end
  end

  # Failing mock parser for error testing
  class FailingMockParser < Lutaml::ModelTransformations::Parsers::BaseParser
    def format_name
      "Failing Mock Format"
    end

    def supported_extensions
      [".fail"]
    end

    protected

    def parse_internal(file_path)
      raise StandardError, "Mock parsing failure"
    end
  end

  let(:mock_config) do
    config = Lutaml::ModelTransformations::Configuration.new
    config.version = "1.0"
    config.parsers = [
      Lutaml::ModelTransformations::Configuration::ParserConfig.new.tap do |p|
        p.format = "mock"
        p.extension = ".mock"
        p.parser_class = "MockParser"
        p.enabled = true
        p.priority = 100
      end
    ]
    config.transformation_options = Lutaml::ModelTransformations::Configuration::TransformationOptions.new
    config.format_detection = Lutaml::ModelTransformations::Configuration::FormatDetection.new
    config.error_handling = Lutaml::ModelTransformations::Configuration::ErrorHandling.new
    config
  end

  let(:engine) { described_class.new(mock_config) }

  describe "#initialize" do
    it "initializes with default configuration when none provided" do
      engine = described_class.new
      expect(engine.configuration).to be_a(Lutaml::ModelTransformations::Configuration)
    end

    it "initializes with provided configuration" do
      engine = described_class.new(mock_config)
      expect(engine.configuration).to eq(mock_config)
    end

    it "initializes format registry" do
      expect(engine.format_registry).to be_a(Lutaml::ModelTransformations::FormatRegistry)
    end

    it "initializes empty transformation history" do
      expect(engine.transformation_history).to be_empty
    end
  end

  describe "#parse" do
    let(:test_file) do
      file = Tempfile.new(["test", ".mock"])
      file.write("mock content")
      file.close
      file
    end

    after { test_file.unlink }

    before do
      # Register mock parser
      engine.register_parser(".mock", MockParser)
    end

    it "successfully parses supported file" do
      result = engine.parse(test_file.path)
      expect(result).to be_a_kind_of(Object)  # Mock document
    end

    it "calls the appropriate parser" do
      parser_instance = nil
      allow(MockParser).to receive(:new) do |*args|
        parser_instance = MockParser.new(*args)
        parser_instance
      end

      engine.parse(test_file.path)
      expect(parser_instance.parse_called_with).to eq(test_file.path)
    end

    it "records successful transformation in history" do
      engine.parse(test_file.path)

      history = engine.transformation_history
      expect(history.size).to eq(1)
      expect(history.first[:success]).to be true
      expect(history.first[:file_path]).to eq(test_file.path)
    end

    it "merges parsing options with configuration" do
      options = { validate_output: true }

      parser_instance = nil
      allow(MockParser).to receive(:new) do |configuration:, options:|
        parser_instance = MockParser.new(configuration: configuration, options: options)
        parser_instance
      end

      engine.parse(test_file.path, options)
      expect(parser_instance.options[:validate_output]).to be true
    end

    context "with unsupported file format" do
      let(:unsupported_file) do
        file = Tempfile.new(["test", ".unsupported"])
        file.write("content")
        file.close
        file
      end

      after { unsupported_file.unlink }

      it "raises UnsupportedFormatError" do
        expect do
          engine.parse(unsupported_file.path)
        end.to raise_error(Lutaml::ModelTransformations::UnsupportedFormatError)
      end
    end

    context "with parsing failure" do
      let(:failing_file) do
        file = Tempfile.new(["test", ".fail"])
        file.write("content")
        file.close
        file
      end

      after { failing_file.unlink }

      before do
        engine.register_parser(".fail", FailingMockParser)
      end

      it "records failed transformation in history" do
        expect do
          engine.parse(failing_file.path)
        end.to raise_error(StandardError)

        history = engine.transformation_history
        expect(history.size).to eq(1)
        expect(history.first[:success]).to be false
        expect(history.first[:error]).to be_a(StandardError)
      end
    end

    context "with invalid file path" do
      it "raises ArgumentError for nil path" do
        expect do
          engine.parse(nil)
        end.to raise_error(ArgumentError, /cannot be nil/)
      end

      it "raises ArgumentError for empty path" do
        expect do
          engine.parse("")
        end.to raise_error(ArgumentError, /cannot be empty/)
      end

      it "raises ArgumentError for non-existent file" do
        expect do
          engine.parse("nonexistent.file")
        end.to raise_error(ArgumentError, /does not exist/)
      end
    end
  end

  describe "#detect_parser" do
    before do
      engine.register_parser(".mock", MockParser)
    end

    context "with file extension detection enabled" do
      it "detects parser by file extension" do
        allow(mock_config.format_detection).to receive(:use_file_extension).and_return(true)

        parser_class = engine.detect_parser("test.mock")
        expect(parser_class).to eq(MockParser)
      end
    end

    context "with content sniffing enabled" do
      let(:test_file) do
        file = Tempfile.new(["test", ".unknown"])
        file.write("mock content")
        file.close
        file
      end

      after { test_file.unlink }

      it "falls back to content detection when extension detection fails" do
        allow(mock_config.format_detection).to receive(:use_file_extension).and_return(false)
        allow(mock_config.format_detection).to receive(:use_content_sniffing).and_return(true)

        # Mock content detection
        allow(engine.format_registry).to receive(:detect_by_content).and_return(MockParser)

        parser_class = engine.detect_parser(test_file.path)
        expect(parser_class).to eq(MockParser)
      end
    end

    context "with fallback parser configured" do
      it "uses fallback parser when detection fails" do
        allow(mock_config.format_detection).to receive(:use_file_extension).and_return(false)
        allow(mock_config.format_detection).to receive(:use_content_sniffing).and_return(false)
        allow(mock_config.format_detection).to receive(:fallback_parser).and_return("MockParser")

        parser_class = engine.detect_parser("unknown.file")
        expect(parser_class).to eq(MockParser)
      end
    end

    it "returns nil when no parser can be detected" do
      allow(mock_config.format_detection).to receive(:use_file_extension).and_return(false)
      allow(mock_config.format_detection).to receive(:use_content_sniffing).and_return(false)
      allow(mock_config.format_detection).to receive(:fallback_parser).and_return(nil)

      parser_class = engine.detect_parser("unknown.file")
      expect(parser_class).to be_nil
    end
  end

  describe "#supported_extensions" do
    before do
      engine.register_parser(".mock", MockParser)
    end

    it "returns list of supported extensions" do
      extensions = engine.supported_extensions
      expect(extensions).to include(".mock")
    end
  end

  describe "#supports_file?" do
    before do
      engine.register_parser(".mock", MockParser)
    end

    it "returns true for supported files" do
      expect(engine.supports_file?("test.mock")).to be true
    end

    it "returns false for unsupported files" do
      expect(engine.supports_file?("test.unsupported")).to be false
    end
  end

  describe "#register_parser" do
    it "registers parser with format registry" do
      engine.register_parser(".test", MockParser)

      parser_class = engine.format_registry.parser_for_extension(".test")
      expect(parser_class).to eq(MockParser)
    end
  end

  describe "#unregister_parser" do
    before do
      engine.register_parser(".test", MockParser)
    end

    it "unregisters parser from format registry" do
      result = engine.unregister_parser(".test")
      expect(result).to eq(MockParser)

      parser_class = engine.format_registry.parser_for_extension(".test")
      expect(parser_class).to be_nil
    end
  end

  describe "#configuration=" do
    let(:new_config) do
      config = Lutaml::ModelTransformations::Configuration.new
      config.version = "2.0"
      config
    end

    it "updates configuration and reloads parsers" do
      original_config = engine.configuration

      engine.configuration = new_config

      expect(engine.configuration).to eq(new_config)
      expect(engine.configuration).not_to eq(original_config)
    end
  end

  describe "#statistics" do
    let(:test_file) do
      file = Tempfile.new(["test", ".mock"])
      file.write("content")
      file.close
      file
    end

    after { test_file.unlink }

    before do
      engine.register_parser(".mock", MockParser)
    end

    it "returns comprehensive statistics" do
      # Perform some transformations
      engine.parse(test_file.path)

      stats = engine.statistics

      expect(stats).to include(
        :total_transformations,
        :successful_transformations,
        :failed_transformations,
        :success_rate,
        :average_duration,
        :supported_extensions,
        :registered_parsers,
        :configuration_version
      )

      expect(stats[:total_transformations]).to eq(1)
      expect(stats[:successful_transformations]).to eq(1)
      expect(stats[:success_rate]).to eq(100.0)
    end

    it "calculates success rate correctly with mixed results" do
      # Register failing parser
      engine.register_parser(".fail", FailingMockParser)

      failing_file = Tempfile.new(["test", ".fail"])
      failing_file.write("content")
      failing_file.close

      begin
        # One success, one failure
        engine.parse(test_file.path)
        begin
          engine.parse(failing_file.path)
        rescue StandardError
          # Expected failure
        end

        stats = engine.statistics
        expect(stats[:total_transformations]).to eq(2)
        expect(stats[:successful_transformations]).to eq(1)
        expect(stats[:failed_transformations]).to eq(1)
        expect(stats[:success_rate]).to eq(50.0)
      ensure
        failing_file.unlink
      end
    end
  end

  describe "#clear_history" do
    let(:test_file) do
      file = Tempfile.new(["test", ".mock"])
      file.write("content")
      file.close
      file
    end

    after { test_file.unlink }

    before do
      engine.register_parser(".mock", MockParser)
    end

    it "clears transformation history" do
      engine.parse(test_file.path)
      expect(engine.transformation_history).not_to be_empty

      engine.clear_history
      expect(engine.transformation_history).to be_empty
    end
  end

  describe "#history_for_file" do
    let(:test_file) do
      file = Tempfile.new(["test", ".mock"])
      file.write("content")
      file.close
      file
    end

    after { test_file.unlink }

    before do
      engine.register_parser(".mock", MockParser)
    end

    it "returns history entries for specific file" do
      engine.parse(test_file.path)
      engine.parse(test_file.path)  # Parse twice

      history = engine.history_for_file(test_file.path)
      expect(history.size).to eq(2)
      expect(history.all? { |entry| entry[:file_path] == test_file.path }).to be true
    end

    it "returns empty array for file with no history" do
      history = engine.history_for_file("nonexistent.file")
      expect(history).to be_empty
    end
  end

  describe "#recent_failures" do
    before do
      engine.register_parser(".fail", FailingMockParser)
    end

    it "returns recent failed transformations" do
      failing_file = Tempfile.new(["test", ".fail"])
      failing_file.write("content")
      failing_file.close

      begin
        # Generate some failures
        3.times do
          begin
            engine.parse(failing_file.path)
          rescue StandardError
            # Expected failures
          end
        end

        failures = engine.recent_failures
        expect(failures.size).to eq(3)
        expect(failures.all? { |entry| !entry[:success] }).to be true
      ensure
        failing_file.unlink
      end
    end

    it "limits number of returned failures" do
      failing_file = Tempfile.new(["test", ".fail"])
      failing_file.write("content")
      failing_file.close

      begin
        # Generate more failures than limit
        5.times do
          begin
            engine.parse(failing_file.path)
          rescue StandardError
            # Expected failures
          end
        end

        failures = engine.recent_failures(2)
        expect(failures.size).to eq(2)
      ensure
        failing_file.unlink
      end
    end
  end

  describe "#validate_setup" do
    before do
      engine.register_parser(".mock", MockParser)
    end

    it "validates configuration and parsers" do
      results = engine.validate_setup

      expect(results).to include(
        :configuration_valid,
        :parsers_loaded,
        :parser_errors,
        :warnings
      )

      expect(results[:configuration_valid]).to be true
      expect(results[:parsers_loaded]).to be > 0
      expect(results[:parser_errors]).to be_an(Array)
    end

    it "detects parser instantiation failures" do
      # Register a non-existent parser class
      allow(engine.format_registry).to receive(:all_parsers).and_return({ ".bad" => String })

      results = engine.validate_setup
      expect(results[:parser_errors]).not_to be_empty
    end
  end

  describe "error handling integration" do
    let(:test_file) do
      file = Tempfile.new(["test", ".mock"])
      file.write("content")
      file.close
      file
    end

    after { test_file.unlink }

    before do
      engine.register_parser(".mock", MockParser)
    end

    it "respects error handling configuration" do
      # Verify that error handling settings are passed to parsers
      parser_instance = nil
      allow(MockParser).to receive(:new) do |configuration:, options:|
        parser_instance = MockParser.new(configuration: configuration, options: options)
        parser_instance
      end

      engine.parse(test_file.path)
      expect(parser_instance.configuration.error_handling).to eq(mock_config.error_handling)
    end
  end
end