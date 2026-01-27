# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lutaml/model_transformations/format_registry"
require_relative "../../../lib/lutaml/model_transformations/parsers/base_parser"
require "tempfile"

RSpec.describe Lutaml::ModelTransformations::FormatRegistry do
  # Mock parser classes for testing
  class MockParser1 < Lutaml::ModelTransformations::Parsers::BaseParser
    def format_name
      "Mock Format 1"
    end

    def supported_extensions
      [".mock1", ".m1"]
    end

    def content_patterns
      [/^MOCK1:/]
    end

    protected

    def parse_internal(file_path)
      # Mock implementation
    end
  end

  class MockParser2 < Lutaml::ModelTransformations::Parsers::BaseParser
    def format_name
      "Mock Format 2"
    end

    def supported_extensions
      [".mock2"]
    end

    def content_patterns
      [/^MOCK2:/, /<mock2>/]
    end

    protected

    def parse_internal(file_path)
      # Mock implementation
    end
  end

  class HighPriorityParser < Lutaml::ModelTransformations::Parsers::BaseParser
    def format_name
      "High Priority Parser"
    end

    def supported_extensions
      [".hp"]
    end

    def priority
      200
    end

    protected

    def parse_internal(file_path)
      # Mock implementation
    end
  end

  class LowPriorityParser < Lutaml::ModelTransformations::Parsers::BaseParser
    def format_name
      "Low Priority Parser"
    end

    def supported_extensions
      [".lp"]
    end

    def priority
      50
    end

    protected

    def parse_internal(file_path)
      # Mock implementation
    end
  end

  let(:registry) { described_class.new }

  describe "#initialize" do
    it "initializes with empty registry" do
      expect(registry.all_parsers).to be_empty
      expect(registry.all_extensions).to be_empty
    end
  end

  describe "#register" do
    it "registers parser for single extension" do
      registry.register(".test", MockParser1)

      expect(registry.parser_for_extension(".test")).to eq(MockParser1)
      expect(registry.all_extensions).to include(".test")
    end

    it "registers parser for multiple extensions" do
      registry.register([".test1", ".test2"], MockParser1)

      expect(registry.parser_for_extension(".test1")).to eq(MockParser1)
      expect(registry.parser_for_extension(".test2")).to eq(MockParser1)
      expect(registry.all_extensions).to include(".test1", ".test2")
    end

    it "normalizes extensions to lowercase with leading dot" do
      registry.register("TEST", MockParser1)
      registry.register(".TEST2", MockParser1)
      registry.register("test3", MockParser1)

      expect(registry.parser_for_extension(".test")).to eq(MockParser1)
      expect(registry.parser_for_extension(".test2")).to eq(MockParser1)
      expect(registry.parser_for_extension(".test3")).to eq(MockParser1)
    end

    it "overwrites existing registration" do
      registry.register(".test", MockParser1)
      registry.register(".test", MockParser2)

      expect(registry.parser_for_extension(".test")).to eq(MockParser2)
    end

    it "validates parser class" do
      expect do
        registry.register(".test", String)
      end.to raise_error(ArgumentError, /must inherit from BaseParser/)
    end

    it "raises error for nil extension" do
      expect do
        registry.register(nil, MockParser1)
      end.to raise_error(ArgumentError, /cannot be nil or empty/)
    end

    it "raises error for empty extension" do
      expect do
        registry.register("", MockParser1)
      end.to raise_error(ArgumentError, /cannot be nil or empty/)
    end

    it "raises error for nil parser class" do
      expect do
        registry.register(".test", nil)
      end.to raise_error(ArgumentError, /cannot be nil/)
    end
  end

  describe "#unregister" do
    before do
      registry.register(".test", MockParser1)
    end

    it "unregisters parser and returns it" do
      result = registry.unregister(".test")
      expect(result).to eq(MockParser1)
      expect(registry.parser_for_extension(".test")).to be_nil
    end

    it "normalizes extension before unregistering" do
      result = registry.unregister("TEST")
      expect(result).to eq(MockParser1)
    end

    it "returns nil for non-existent extension" do
      result = registry.unregister(".nonexistent")
      expect(result).to be_nil
    end
  end

  describe "#parser_for_extension" do
    before do
      registry.register(".test", MockParser1)
    end

    it "returns parser for registered extension" do
      expect(registry.parser_for_extension(".test")).to eq(MockParser1)
    end

    it "normalizes extension before lookup" do
      expect(registry.parser_for_extension("TEST")).to eq(MockParser1)
      expect(registry.parser_for_extension("test")).to eq(MockParser1)
      expect(registry.parser_for_extension(".TEST")).to eq(MockParser1)
    end

    it "returns nil for unregistered extension" do
      expect(registry.parser_for_extension(".unknown")).to be_nil
    end
  end

  describe "#detect_by_content" do
    let(:test_file) { Tempfile.new(["test", ".txt"]) }

    after { test_file.unlink }

    before do
      registry.register(".mock1", MockParser1)
      registry.register(".mock2", MockParser2)
    end

    it "detects parser by content pattern" do
      test_file.write("MOCK1: test content")
      test_file.close

      parser_class = registry.detect_by_content(test_file.path)
      expect(parser_class).to eq(MockParser1)
    end

    it "returns first matching parser for multiple matches" do
      test_file.write("MOCK1: test content")
      test_file.close

      # Register another parser that might also match
      registry.register(".another", MockParser2)

      parser_class = registry.detect_by_content(test_file.path)
      expect(parser_class).to eq(MockParser1)
    end

    it "returns nil when no patterns match" do
      test_file.write("no matching content")
      test_file.close

      parser_class = registry.detect_by_content(test_file.path)
      expect(parser_class).to be_nil
    end

    it "handles multiple content patterns" do
      test_file.write("<mock2>content</mock2>")
      test_file.close

      parser_class = registry.detect_by_content(test_file.path)
      expect(parser_class).to eq(MockParser2)
    end

    it "raises error for non-existent file" do
      expect do
        registry.detect_by_content("nonexistent.file")
      end.to raise_error(ArgumentError, /does not exist/)
    end

    it "handles large files efficiently" do
      # Write large content but matching pattern is at the beginning
      test_file.write("MOCK1: #{' ' * 10000}")
      test_file.close

      parser_class = registry.detect_by_content(test_file.path)
      expect(parser_class).to eq(MockParser1)
    end
  end

  describe "#supports_extension?" do
    before do
      registry.register(".test", MockParser1)
    end

    it "returns true for supported extension" do
      expect(registry.supports_extension?(".test")).to be true
    end

    it "normalizes extension before checking" do
      expect(registry.supports_extension?("TEST")).to be true
      expect(registry.supports_extension?("test")).to be true
    end

    it "returns false for unsupported extension" do
      expect(registry.supports_extension?(".unknown")).to be false
    end
  end

  describe "#all_parsers" do
    before do
      registry.register(".test1", MockParser1)
      registry.register(".test2", MockParser2)
    end

    it "returns hash of all registered parsers" do
      parsers = registry.all_parsers
      expect(parsers).to eq({
        ".test1" => MockParser1,
        ".test2" => MockParser2
      })
    end

    it "returns defensive copy" do
      parsers1 = registry.all_parsers
      parsers2 = registry.all_parsers
      expect(parsers1).not_to be(parsers2)
    end
  end

  describe "#all_extensions" do
    before do
      registry.register([".test1", ".test2"], MockParser1)
      registry.register(".test3", MockParser2)
    end

    it "returns array of all registered extensions" do
      extensions = registry.all_extensions
      expect(extensions).to contain_exactly(".test1", ".test2", ".test3")
    end

    it "returns defensive copy" do
      extensions1 = registry.all_extensions
      extensions2 = registry.all_extensions
      expect(extensions1).not_to be(extensions2)
    end
  end

  describe "#parsers_by_priority" do
    before do
      registry.register(".hp", HighPriorityParser)
      registry.register(".lp", LowPriorityParser)
      registry.register(".mock", MockParser1) # Default priority
    end

    it "returns parsers sorted by priority (highest first)" do
      parsers = registry.parsers_by_priority

      expect(parsers.map(&:last)).to eq([
        HighPriorityParser,
        MockParser1, # Default priority (100)
        LowPriorityParser
      ])
    end

    it "includes extension information" do
      parsers = registry.parsers_by_priority
      high_priority_entry = parsers.find do |_ext, parser|
        parser == HighPriorityParser
      end

      expect(high_priority_entry.first).to include(".hp")
    end
  end

  describe "#clear" do
    before do
      registry.register(".test1", MockParser1)
      registry.register(".test2", MockParser2)
    end

    it "removes all registered parsers" do
      registry.clear

      expect(registry.all_parsers).to be_empty
      expect(registry.all_extensions).to be_empty
    end
  end

  describe "#statistics" do
    before do
      registry.register([".m1", ".m2"], MockParser1)
      registry.register(".m3", MockParser2)
    end

    it "returns comprehensive statistics" do
      stats = registry.statistics

      expect(stats).to include(
        :total_parsers,
        :total_extensions,
        :extensions_per_parser,
        :parser_details,
      )

      expect(stats[:total_parsers]).to eq(2)
      expect(stats[:total_extensions]).to eq(3)
      expect(stats[:extensions_per_parser]).to eq(1.5)
    end

    it "includes parser details with priorities" do
      stats = registry.statistics

      parser_details = stats[:parser_details]
      expect(parser_details).to be_an(Array)
      expect(parser_details.size).to eq(2)

      detail = parser_details.find { |d| d[:parser] == MockParser1 }
      expect(detail).to include(:parser, :extensions, :priority, :format_name)
    end
  end

  describe "#auto_register_from_parser" do
    it "registers parser for its supported extensions" do
      registry.auto_register_from_parser(MockParser1)

      expect(registry.parser_for_extension(".mock1")).to eq(MockParser1)
      expect(registry.parser_for_extension(".m1")).to eq(MockParser1)
    end

    it "validates parser before registration" do
      expect do
        registry.auto_register_from_parser(String)
      end.to raise_error(ArgumentError, /Extension cannot be nil or empty/)
    end
  end

  describe "#export_configuration" do
    before do
      registry.register(".mock1", MockParser1)
      registry.register(".mock2", MockParser2)
    end

    it "exports registry configuration" do
      config = registry.export_configuration

      expect(config).to include(:parsers, :exported_at)
      expect(config[:parsers]).to be_an(Array)
      expect(config[:parsers].size).to eq(2)
    end

    it "includes parser metadata in export" do
      config = registry.export_configuration

      parser_config = config[:parsers].find do |p|
        p[:format] == "Mock Format 1"
      end
      expect(parser_config).to include(
        :format,
        :parser_class,
        :extensions,
        :priority,
      )
    end
  end

  describe "thread safety" do
    it "handles concurrent registration safely" do
      threads = []

      10.times do |i|
        threads << Thread.new do
          registry.register(".thread#{i}", MockParser1)
        end
      end

      threads.each(&:join)

      expect(registry.all_extensions.size).to eq(10)
    end

    it "handles concurrent access safely" do
      registry.register(".test", MockParser1)

      threads = []
      results = []

      10.times do
        threads << Thread.new do
          results << registry.parser_for_extension(".test")
        end
      end

      threads.each(&:join)

      expect(results.all? { |r| r == MockParser1 }).to be true
    end
  end

  describe "edge cases" do
    it "handles extensions with multiple dots" do
      registry.register(".tar.gz", MockParser1)
      expect(registry.parser_for_extension(".tar.gz")).to eq(MockParser1)
    end

    it "handles very long extension names" do
      long_ext = ".#{'a' * 100}"
      registry.register(long_ext, MockParser1)
      expect(registry.parser_for_extension(long_ext)).to eq(MockParser1)
    end

    it "handles special characters in extensions" do
      registry.register(".test-1_2", MockParser1)
      expect(registry.parser_for_extension(".test-1_2")).to eq(MockParser1)
    end
  end
end
