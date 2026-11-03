# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/spa"

RSpec.describe "SVG Diagram Generation Integration" do
  let(:schema_name) { "test_schema" }

  describe "Element diagram generation" do
    it "generates valid SVG for a simple element" do
      element_data = {
        "name" => "TestElement",
        "type" => "string",
        "kind" => "element",
      }

      generator = Lutaml::Xsd::Spa::Svg::DiagramGenerator.new(schema_name)
      svg = generator.generate_element_diagram(element_data)

      expect(svg).to include("<svg")
      expect(svg).to include("TestElement")
      expect(svg).to include("</svg>")
    end

    it "generates SVG with gradients when enabled" do
      element_data = {
        "name" => "TestElement",
        "kind" => "element",
      }

      generator = Lutaml::Xsd::Spa::Svg::DiagramGenerator.new(schema_name)
      svg = generator.generate_element_diagram(element_data)

      expect(svg).to include("linearGradient")
      expect(svg).to include("elementGradient")
    end

    it "generates SVG with attributes" do
      element_data = {
        "name" => "Book",
        "type" => "BookType",
        "kind" => "element",
        "attributes" => [
          { "name" => "isbn", "type" => "string", "kind" => "attribute" },
          { "name" => "year", "type" => "integer", "kind" => "attribute" },
        ],
      }

      generator = Lutaml::Xsd::Spa::Svg::DiagramGenerator.new(schema_name)
      svg = generator.generate_element_diagram(element_data)

      expect(svg).to include("<svg")
      expect(svg).to include("Book")
      expect(svg).to include("</svg>")
    end
  end

  describe "Type diagram generation" do
    it "generates valid SVG for a complex type" do
      type_data = {
        "name" => "TestType",
        "kind" => "type",
        "attributes" => [
          { "name" => "id", "type" => "string", "kind" => "attribute" },
        ],
      }

      generator = Lutaml::Xsd::Spa::Svg::DiagramGenerator.new(schema_name)
      svg = generator.generate_type_diagram(type_data)

      expect(svg).to include("<svg")
      expect(svg).to include("TestType")
      expect(svg).to include("</svg>")
    end

    it "generates SVG with base type inheritance" do
      type_data = {
        "name" => "ExtendedType",
        "kind" => "type",
        "base_type" => "BaseType",
        "attributes" => [],
      }

      generator = Lutaml::Xsd::Spa::Svg::DiagramGenerator.new(schema_name)
      svg = generator.generate_type_diagram(type_data)

      expect(svg).to include("<svg")
      expect(svg).to include("ExtendedType")
      expect(svg).to include("</svg>")
    end

    it "generates SVG with content model" do
      type_data = {
        "name" => "AddressType",
        "kind" => "type",
        "content_model" => {
          "type" => "sequence",
          "elements" => [
            { "name" => "street", "min_occurs" => "1", "max_occurs" => "1",
              "kind" => "element" },
            { "name" => "city", "min_occurs" => "1", "max_occurs" => "1",
              "kind" => "element" },
          ],
        },
      }

      generator = Lutaml::Xsd::Spa::Svg::DiagramGenerator.new(schema_name)
      svg = generator.generate_type_diagram(type_data)

      expect(svg).to include("<svg")
      expect(svg).to include("AddressType")
      expect(svg).to include("</svg>")
    end
  end

  describe "Error handling" do
    it "returns error SVG for invalid data" do
      generator = Lutaml::Xsd::Spa::Svg::DiagramGenerator.new(schema_name)

      # This should trigger error handling
      svg = generator.generate_element_diagram(nil)

      expect(svg).to include("<svg")
      expect(svg).to include("Error:")
    end

    it "handles missing component data gracefully" do
      generator = Lutaml::Xsd::Spa::Svg::DiagramGenerator.new(schema_name)

      svg = generator.generate_element_diagram({})

      expect(svg).to include("<svg")
    end
  end

  describe "SVG structure validation" do
    it "includes proper SVG namespace" do
      element_data = {
        "name" => "Test",
        "kind" => "element",
      }

      generator = Lutaml::Xsd::Spa::Svg::DiagramGenerator.new(schema_name)
      svg = generator.generate_element_diagram(element_data)

      expect(svg).to include('xmlns="http://www.w3.org/2000/svg"')
    end

    it "includes gradient definitions" do
      element_data = {
        "name" => "Test",
        "kind" => "element",
      }

      generator = Lutaml::Xsd::Spa::Svg::DiagramGenerator.new(schema_name)
      svg = generator.generate_element_diagram(element_data)

      expect(svg).to include("<defs>")
      expect(svg).to include("</defs>")
      expect(svg).to include("linearGradient")
    end

    it "generates well-formed SVG" do
      element_data = {
        "name" => "Test",
        "kind" => "element",
      }

      generator = Lutaml::Xsd::Spa::Svg::DiagramGenerator.new(schema_name)
      svg = generator.generate_element_diagram(element_data)

      # Check that SVG tags are properly closed
      expect(svg.scan("<svg").length).to eq(svg.scan("</svg>").length)
      expect(svg).to start_with("<svg")
      expect(svg).to end_with("</svg>\n")
    end
  end

  describe "Configuration support" do
    it "accepts custom configuration" do
      config = Lutaml::Xsd::Spa::Svg::StyleConfiguration.load

      generator = Lutaml::Xsd::Spa::Svg::DiagramGenerator.new(schema_name,
                                                              config)

      element_data = {
        "name" => "Test",
        "kind" => "element",
      }

      svg = generator.generate_element_diagram(element_data)

      expect(svg).to include("<svg")
      expect(svg).to include("</svg>")
    end

    it "uses default configuration when none provided" do
      generator = Lutaml::Xsd::Spa::Svg::DiagramGenerator.new(schema_name)

      element_data = {
        "name" => "Test",
        "kind" => "element",
      }

      svg = generator.generate_element_diagram(element_data)

      expect(svg).to include("<svg")
      expect(svg).to include("</svg>")
    end
  end
end
