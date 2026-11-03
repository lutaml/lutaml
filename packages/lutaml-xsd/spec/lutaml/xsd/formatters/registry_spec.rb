# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/xsd/formatters/registry"

RSpec.describe Lutaml::Xsd::Formatters::Registry do
  let(:registry) { described_class.new }
  let(:base_formatter) { Lutaml::Xsd::Formatters::Base }

  # Create a test formatter class
  let(:test_formatter_class) do
    Class.new(base_formatter) do
      def format(_results)
        "test output"
      end
    end
  end

  # Create another test formatter class
  let(:another_formatter_class) do
    Class.new(base_formatter) do
      def format(_results)
        "another output"
      end
    end
  end

  describe "#register" do
    it "registers a formatter class" do
      registry.register("test", test_formatter_class)
      expect(registry.supported?("test")).to be true
    end

    it "accepts string format names" do
      registry.register("test", test_formatter_class)
      expect(registry.supported?("test")).to be true
    end

    it "accepts symbol format names" do
      registry.register(:test, test_formatter_class)
      expect(registry.supported?("test")).to be true
    end

    it "raises ArgumentError if class doesn't inherit from Base" do
      invalid_class = Class.new
      expect do
        registry.register("invalid", invalid_class)
      end.to raise_error(
        ArgumentError,
        /Formatter must inherit from.*Base/,
      )
    end

    it "allows overwriting existing formatter" do
      registry.register("test", test_formatter_class)
      registry.register("test", another_formatter_class)

      formatter = registry.create("test")
      expect(formatter.format({})).to eq("another output")
    end
  end

  describe "#create" do
    before do
      registry.register("test", test_formatter_class)
    end

    it "creates formatter instance" do
      formatter = registry.create("test")
      expect(formatter).to be_a(base_formatter)
    end

    it "creates working formatter" do
      formatter = registry.create("test")
      expect(formatter.format({})).to eq("test output")
    end

    it "accepts string format names" do
      formatter = registry.create("test")
      expect(formatter).to be_a(base_formatter)
    end

    it "accepts symbol format names" do
      formatter = registry.create(:test)
      expect(formatter).to be_a(base_formatter)
    end

    it "raises ArgumentError for unknown format" do
      expect do
        registry.create("unknown")
      end.to raise_error(
        ArgumentError,
        /Unknown format: unknown/,
      )
    end

    it "includes supported formats in error message" do
      registry.register("format1", test_formatter_class)
      registry.register("format2", another_formatter_class)

      expect do
        registry.create("unknown")
      end.to raise_error(
        ArgumentError,
        /Supported formats: format1, format2/,
      )
    end
  end

  describe "#supported_formats" do
    it "returns empty array when no formatters registered" do
      expect(registry.supported_formats).to eq([])
    end

    it "returns array of registered format names" do
      registry.register("test1", test_formatter_class)
      registry.register("test2", another_formatter_class)

      expect(registry.supported_formats).to contain_exactly("test1", "test2")
    end

    it "returns sorted array" do
      registry.register("zebra", test_formatter_class)
      registry.register("alpha", another_formatter_class)

      expect(registry.supported_formats).to eq(["alpha", "zebra"])
    end
  end

  describe "#supported?" do
    before do
      registry.register("test", test_formatter_class)
    end

    it "returns true for registered format" do
      expect(registry.supported?("test")).to be true
    end

    it "returns false for unregistered format" do
      expect(registry.supported?("unknown")).to be false
    end

    it "accepts string format names" do
      expect(registry.supported?("test")).to be true
    end

    it "accepts symbol format names" do
      expect(registry.supported?(:test)).to be true
    end
  end

  describe "#unregister" do
    before do
      registry.register("test", test_formatter_class)
    end

    it "removes registered formatter" do
      registry.unregister("test")
      expect(registry.supported?("test")).to be false
    end

    it "returns removed formatter class" do
      removed = registry.unregister("test")
      expect(removed).to eq(test_formatter_class)
    end

    it "returns nil for non-existent format" do
      removed = registry.unregister("nonexistent")
      expect(removed).to be_nil
    end

    it "accepts string format names" do
      registry.unregister("test")
      expect(registry.supported?("test")).to be false
    end

    it "accepts symbol format names" do
      registry.unregister(:test)
      expect(registry.supported?("test")).to be false
    end
  end

  describe "#clear" do
    it "removes all registered formatters" do
      registry.register("test1", test_formatter_class)
      registry.register("test2", another_formatter_class)

      registry.clear

      expect(registry.supported?("test1")).to be false
      expect(registry.supported?("test2")).to be false
      expect(registry.supported_formats).to be_empty
    end
  end

  describe "#count" do
    it "returns 0 when no formatters registered" do
      expect(registry.count).to eq(0)
    end

    it "returns number of registered formatters" do
      registry.register("test1", test_formatter_class)
      registry.register("test2", another_formatter_class)

      expect(registry.count).to eq(2)
    end

    it "updates after unregister" do
      registry.register("test1", test_formatter_class)
      registry.register("test2", another_formatter_class)
      registry.unregister("test1")

      expect(registry.count).to eq(1)
    end
  end
end
