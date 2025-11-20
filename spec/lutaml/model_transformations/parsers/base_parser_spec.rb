# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/model_transformations/parsers/base_parser"
require_relative "../../../../lib/lutaml/model_transformations/configuration"
require "tempfile"

RSpec.describe Lutaml::ModelTransformations::Parsers::BaseParser do
  # Concrete test parser for testing abstract base
  class TestParser < described_class
    attr_reader :parse_internal_called_with, :validate_input_called, :validate_output_called

    def format_name
      "Test Format"
    end

    def supported_extensions
      [".test"]
    end

    def content_patterns
      [/^TEST:/]
    end

    def priority
      150
    end

    protected

    def parse_internal(file_path)
      @parse_internal_called_with = file_path

      # Create a mock UML document
      doc = double("Lutaml::Uml::Document")
      allow(doc).to receive(:packages).and_return([])
      allow(doc).to receive(:classes).and_return([])
      allow(doc).to receive(:is_a?).with(Lutaml::Uml::Document).and_return(true)
      doc
    end

    def validate_input(file_path)
      @validate_input_called = true
      super
    end

    def validate_output(result)
      @validate_output_called = true
      super
    end
  end

  # Failing test parser for error testing
  class FailingTestParser < described_class
    def format_name
      "Failing Test Format"
    end

    def supported_extensions
      [".fail"]
    end

    protected

    def parse_internal(file_path)
      raise StandardError, "Simulated parsing failure"
    end
  end

  # Parser with custom validation
  class ValidatingTestParser < described_class
    def format_name
      "Validating Test Format"
    end

    def supported_extensions
      [".validate"]
    end

    protected

    def parse_internal(file_path)
      # Return mock document
      doc = double("Lutaml::Uml::Document")
      allow(doc).to receive(:packages).and_return([])
      allow(doc).to receive(:classes).and_return([])
      allow(doc).to receive(:is_a?).with(Lutaml::Uml::Document).and_return(true)
      doc
    end

    def validate_input(file_path)
      content = File.read(file_path)
      raise ArgumentError, "Invalid content" unless content.include?("VALID")
    end

    def validate_output(result)
      raise RuntimeError, "Invalid output" if result.nil?
    end
  end

  let(:configuration) { Lutaml::ModelTransformations::Configuration.new }
  let(:options) { {} }
  let(:parser) { TestParser.new(configuration: configuration, options: options) }

  describe "#initialize" do
    it "initializes with configuration and options" do
      expect(parser.configuration).to eq(configuration)
      expect(parser.options).to eq(options)
    end

    it "merges options with defaults" do
      custom_options = { validate_input: false }
      parser = TestParser.new(configuration: configuration, options: custom_options)

      expect(parser.options[:validate_input]).to be false
      expect(parser.options).to include(:validate_output)  # Default option
    end

    it "requires configuration parameter" do
      expect do
        TestParser.new(options: options)
      end.to raise_error(ArgumentError, /missing keyword: configuration/)
    end
  end

  describe "#parse" do
    let(:test_file) do
      file = Tempfile.new(["test", ".test"])
      file.write("TEST: valid content")
      file.close
      file
    end

    after { test_file.unlink }

    it "successfully parses valid file" do
      result = parser.parse(test_file.path)
      expect(result).to be_truthy
      expect(parser.parse_internal_called_with).to eq(test_file.path)
    end

    it "validates input when enabled" do
      parser.options[:validate_input] = true
      parser.parse(test_file.path)
      expect(parser.validate_input_called).to be true
    end

    it "validates output when enabled" do
      parser.options[:validate_output] = true
      parser.parse(test_file.path)
      expect(parser.validate_output_called).to be true
    end

    it "skips input validation when disabled" do
      parser.options[:validate_input] = false
      parser.parse(test_file.path)
      expect(parser.validate_input_called).to be_falsy
    end

    it "measures parsing duration" do
      result = parser.parse(test_file.path)
      expect(parser.last_duration).to be > 0
    end

    it "records transformation statistics" do
      parser.parse(test_file.path)

      stats = parser.statistics
      expect(stats[:total_parses]).to eq(1)
      expect(stats[:successful_parses]).to eq(1)
      expect(stats[:failed_parses]).to eq(0)
    end

    context "with input validation failure" do
      let(:parser) { ValidatingTestParser.new(configuration: configuration, options: { validate_input: true }) }

      let(:invalid_file) do
        file = Tempfile.new(["invalid", ".validate"])
        file.write("INVALID content")
        file.close
        file
      end

      after { invalid_file.unlink }

      it "raises validation error" do
        expect do
          parser.parse(invalid_file.path)
        end.to raise_error(ArgumentError, "Invalid content")
      end

      it "records failed parse in statistics" do
        begin
          parser.parse(invalid_file.path)
        rescue ArgumentError
          # Expected error
        end

        stats = parser.statistics
        expect(stats[:failed_parses]).to eq(1)
        expect(stats[:total_parses]).to eq(1)
      end
    end

    context "with parsing failure" do
      let(:parser) { FailingTestParser.new(configuration: configuration, options: options) }

      let(:test_file) do
        file = Tempfile.new(["test", ".fail"])
        file.write("content")
        file.close
        file
      end

      after { test_file.unlink }

      it "raises parsing error" do
        expect do
          parser.parse(test_file.path)
        end.to raise_error(StandardError, "Simulated parsing failure")
      end

      it "records failed parse in statistics" do
        begin
          parser.parse(test_file.path)
        rescue StandardError
          # Expected error
        end

        stats = parser.statistics
        expect(stats[:failed_parses]).to eq(1)
      end
    end

    context "with invalid file path" do
      it "raises error for nil path" do
        expect do
          parser.parse(nil)
        end.to raise_error(ArgumentError, /File path cannot be nil or empty/)
      end

      it "raises error for empty path" do
        expect do
          parser.parse("")
        end.to raise_error(ArgumentError, /File path cannot be nil or empty/)
      end

      it "raises error for non-existent file" do
        expect do
          parser.parse("nonexistent.file")
        end.to raise_error(ArgumentError, /File does not exist/)
      end
    end
  end

  describe "#can_parse?" do
    let(:test_file) do
      file = Tempfile.new(["test", ".test"])
      file.write("TEST: content")
      file.close
      file
    end

    after { test_file.unlink }

    it "returns true for supported extension" do
      expect(parser.can_parse?(test_file.path)).to be true
    end

    it "returns false for unsupported extension" do
      unsupported_file = Tempfile.new(["test", ".unsupported"])
      unsupported_file.close

      begin
        expect(parser.can_parse?(unsupported_file.path)).to be false
      ensure
        unsupported_file.unlink
      end
    end

    it "checks content patterns when extension check fails" do
      # File with unsupported extension but matching content
      content_file = Tempfile.new(["test", ".unknown"])
      content_file.write("TEST: matching content")
      content_file.close

      begin
        expect(parser.can_parse?(content_file.path)).to be true
      ensure
        content_file.unlink
      end
    end

    it "returns false when both extension and content checks fail" do
      non_matching_file = Tempfile.new(["test", ".unknown"])
      non_matching_file.write("no matching content")
      non_matching_file.close

      begin
        expect(parser.can_parse?(non_matching_file.path)).to be false
      ensure
        non_matching_file.unlink
      end
    end
  end

  describe "#statistics" do
    let(:test_file) do
      file = Tempfile.new(["test", ".test"])
      file.write("TEST: content")
      file.close
      file
    end

    after { test_file.unlink }

    it "returns comprehensive statistics" do
      parser.parse(test_file.path)

      stats = parser.statistics
      expect(stats).to include(
        :total_parses,
        :successful_parses,
        :failed_parses,
        :success_rate,
        :average_duration,
        :total_duration,
        :format_name,
        :supported_extensions,
        :priority
      )
    end

    it "calculates success rate correctly" do
      # One success
      parser.parse(test_file.path)

      # One failure
      failing_parser = FailingTestParser.new(configuration: configuration, options: options)
      begin
        failing_parser.parse(test_file.path)
      rescue StandardError
        # Expected failure
      end

      stats = parser.statistics
      expect(stats[:success_rate]).to eq(100.0)

      failing_stats = failing_parser.statistics
      expect(failing_stats[:success_rate]).to eq(0.0)
    end

    it "calculates average duration" do
      parser.parse(test_file.path)
      parser.parse(test_file.path)

      stats = parser.statistics
      expect(stats[:average_duration]).to be > 0
      expect(stats[:total_duration]).to be > stats[:average_duration]
    end
  end

  describe "#reset_statistics" do
    let(:test_file) do
      file = Tempfile.new(["test", ".test"])
      file.write("TEST: content")
      file.close
      file
    end

    after { test_file.unlink }

    it "resets all statistics" do
      parser.parse(test_file.path)

      stats_before = parser.statistics
      expect(stats_before[:total_parses]).to eq(1)

      parser.reset_statistics

      stats_after = parser.statistics
      expect(stats_after[:total_parses]).to eq(0)
      expect(stats_after[:successful_parses]).to eq(0)
      expect(stats_after[:failed_parses]).to eq(0)
      expect(stats_after[:total_duration]).to eq(0)
    end
  end

  describe "abstract method enforcement" do
    # Abstract test class that doesn't implement required methods
    class AbstractTestParser < described_class
    end

    let(:abstract_parser) { AbstractTestParser.new(configuration: configuration, options: options) }

    it "raises NotImplementedError for format_name" do
      expect do
        abstract_parser.format_name
      end.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for supported_extensions" do
      expect do
        abstract_parser.supported_extensions
      end.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for parse_internal" do
      test_file = Tempfile.new(["test", ".test"])
      test_file.close

      begin
        expect do
          abstract_parser.send(:parse_internal, test_file.path)
        end.to raise_error(NotImplementedError)
      ensure
        test_file.unlink
      end
    end
  end

  describe "default implementations" do
    it "provides default content_patterns" do
      expect(parser.content_patterns).to eq([/^TEST:/])
    end

    it "provides default priority" do
      expect(parser.priority).to eq(150)
    end

    it "provides default validate_input" do
      test_file = Tempfile.new(["test", ".test"])
      test_file.close

      begin
        expect do
          parser.send(:validate_input, test_file.path)
        end.not_to raise_error
      ensure
        test_file.unlink
      end
    end

    it "provides default validate_output" do
      mock_result = double("result")
      expect do
        parser.send(:validate_output, mock_result)
      end.not_to raise_error
    end
  end

  describe "configuration integration" do
    it "accesses configuration settings" do
      configuration.version = "test_version"
      expect(parser.configuration.version).to eq("test_version")
    end

    it "respects error handling configuration" do
      configuration.error_handling = Lutaml::ModelTransformations::Configuration::ErrorHandling.new
      configuration.error_handling.max_retries = 3

      expect(parser.configuration.error_handling.max_retries).to eq(3)
    end
  end

  describe "options handling" do
    it "provides default options" do
      default_parser = TestParser.new(configuration: configuration)
      expect(default_parser.options).to include(
        :validate_input,
        :validate_output,
        :timeout,
        :memory_limit
      )
    end

    it "allows option overrides" do
      custom_options = {
        validate_input: false,
        timeout: 30,
        custom_option: "value"
      }

      custom_parser = TestParser.new(configuration: configuration, options: custom_options)
      expect(custom_parser.options[:validate_input]).to be false
      expect(custom_parser.options[:timeout]).to eq(30)
      expect(custom_parser.options[:custom_option]).to eq("value")
    end
  end

  describe "error handling" do
    let(:test_file) do
      file = Tempfile.new(["test", ".test"])
      file.write("TEST: content")
      file.close
      file
    end

    after { test_file.unlink }

    it "handles file reading errors gracefully" do
      # Mock File.read to raise an error
      allow(File).to receive(:read).with(test_file.path).and_raise(IOError, "Read error")

      expect do
        parser.can_parse?(test_file.path)
      end.not_to raise_error

      # Should fall back to extension-based detection
      expect(parser.can_parse?(test_file.path)).to be true
    end

    it "preserves original errors from parse_internal" do
      failing_parser = FailingTestParser.new(configuration: configuration, options: options)

      expect do
        failing_parser.parse(test_file.path)
      end.to raise_error(StandardError, "Simulated parsing failure")
    end
  end

  describe "thread safety" do
    let(:test_file) do
      file = Tempfile.new(["test", ".test"])
      file.write("TEST: content")
      file.close
      file
    end

    after { test_file.unlink }

    it "handles concurrent parsing safely" do
      threads = []
      results = []

      5.times do
        threads << Thread.new do
          result = parser.parse(test_file.path)
          results << result
        end
      end

      threads.each(&:join)

      expect(results.size).to eq(5)
      expect(results.all?(&:present?)).to be true

      stats = parser.statistics
      expect(stats[:total_parses]).to eq(5)
      expect(stats[:successful_parses]).to eq(5)
    end
  end
end