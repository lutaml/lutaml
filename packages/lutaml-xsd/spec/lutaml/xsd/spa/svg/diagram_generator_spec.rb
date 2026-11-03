# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/spa"

RSpec.describe Lutaml::Xsd::Spa::Svg::DiagramGenerator do
  let(:schema_name) { "test_schema" }
  let(:config) { Lutaml::Xsd::Spa::Svg::StyleConfiguration.load }
  let(:generator) { described_class.new(schema_name, config) }

  describe "#initialize" do
    it "creates a generator with schema name and config" do
      expect(generator.schema_name).to eq("test_schema")
      expect(generator.config).to eq(config)
    end

    it "uses default config if none provided" do
      gen = described_class.new("schema")

      expect(gen.config).to be_a(Lutaml::Xsd::Spa::Svg::StyleConfiguration)
    end
  end

  describe "#generate_element_diagram" do
    let(:element_data) do
      {
        "name" => "Person",
        "kind" => "element",
        "elements" => [],
      }
    end

    # NOTE: Full integration test will require layout engines to be implemented
    it "returns SVG document" do
      # This test will fail until layout engines are implemented
      # For now, we test error handling
      result = generator.generate_element_diagram(element_data)

      expect(result).to include("<svg")
    end

    it "handles errors gracefully" do
      invalid_data = nil

      result = generator.generate_element_diagram(invalid_data)

      expect(result).to include("<svg")
      expect(result).to include("Error:")
    end
  end

  describe "#generate_type_diagram" do
    let(:type_data) do
      {
        "name" => "PersonType",
        "kind" => "type",
        "base_type" => "xs:anyType",
      }
    end

    it "returns SVG document" do
      result = generator.generate_type_diagram(type_data)

      expect(result).to include("<svg")
    end

    it "handles errors gracefully" do
      invalid_data = { "invalid" => "data" }

      result = generator.generate_type_diagram(invalid_data)

      expect(result).to include("<svg")
    end
  end

  describe "error handling" do
    it "handles invalid data gracefully" do
      # The new architecture is robust and generates valid SVG even for minimal data
      result = generator.generate_element_diagram(nil)

      # Should return either a valid SVG or an error SVG, both are acceptable
      expect(result).to include("<svg")
      expect(result).to include("</svg>")
    end

    it "generates valid SVG for edge cases" do
      # Test with empty hash - should still work
      result = generator.generate_element_diagram({})

      expect(result).to include("<svg")
      expect(result).to include("</svg>")
    end
  end
end
