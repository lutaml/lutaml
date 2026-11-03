# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../lib/lutaml/xsd/formatters/formatter_factory"

RSpec.describe Lutaml::Xsd::Formatters::FormatterFactory do
  describe ".create" do
    context "with text format" do
      it "creates a TextFormatter instance" do
        formatter = described_class.create("text")
        expect(formatter).to be_a(Lutaml::Xsd::Formatters::TextFormatter)
      end
    end

    context "with json format" do
      it "creates a JsonFormatter instance" do
        formatter = described_class.create("json")
        expect(formatter).to be_a(Lutaml::Xsd::Formatters::JsonFormatter)
      end
    end

    context "with yaml format" do
      it "creates a YamlFormatter instance" do
        formatter = described_class.create("yaml")
        expect(formatter).to be_a(Lutaml::Xsd::Formatters::YamlFormatter)
      end
    end

    context "with unknown format" do
      it "raises ArgumentError" do
        expect do
          described_class.create("unknown")
        end.to raise_error(ArgumentError, /Unknown format: unknown/)
      end
    end

    context "with nil format" do
      it "raises ArgumentError" do
        expect do
          described_class.create(nil)
        end.to raise_error(ArgumentError)
      end
    end

    context "with empty string format" do
      it "raises ArgumentError" do
        expect do
          described_class.create("")
        end.to raise_error(ArgumentError)
      end
    end
  end

  describe ".supported_formats" do
    it "returns array of supported format names" do
      formats = described_class.supported_formats
      expect(formats).to be_an(Array)
      expect(formats).to include("text", "json", "yaml")
    end

    it "returns exactly three formats" do
      expect(described_class.supported_formats.size).to eq(3)
    end
  end

  describe ".supported?" do
    context "with supported formats" do
      it "returns true for text" do
        expect(described_class.supported?("text")).to be true
      end

      it "returns true for json" do
        expect(described_class.supported?("json")).to be true
      end

      it "returns true for yaml" do
        expect(described_class.supported?("yaml")).to be true
      end
    end

    context "with unsupported formats" do
      it "returns false for unknown format" do
        expect(described_class.supported?("xml")).to be false
      end

      it "returns false for nil" do
        expect(described_class.supported?(nil)).to be false
      end

      it "returns false for empty string" do
        expect(described_class.supported?("")).to be false
      end
    end
  end

  describe "formatter instances" do
    it "creates independent instances" do
      formatter1 = described_class.create("text")
      formatter2 = described_class.create("text")
      expect(formatter1).not_to be(formatter2)
    end

    it "all created formatters respond to format method" do
      %w[text json yaml].each do |format|
        formatter = described_class.create(format)
        expect(formatter).to respond_to(:format)
      end
    end
  end
end
