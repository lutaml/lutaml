# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/spa/svg/component_renderer"
require "lutaml/xsd/spa/svg/style_configuration"
require "lutaml/xsd/spa/svg/geometry/box"

RSpec.describe Lutaml::Xsd::Spa::Svg::ComponentRenderer do
  let(:config) { Lutaml::Xsd::Spa::Svg::StyleConfiguration.new({}, {}) }
  let(:schema_name) { "test_schema" }
  let(:renderer) { described_class.new(config, schema_name) }

  describe "#initialize" do
    it "stores config and schema_name" do
      expect(renderer.config).to eq(config)
      expect(renderer.schema_name).to eq(schema_name)
    end
  end

  describe "#render" do
    it "raises NotImplementedError for abstract base class" do
      box = Lutaml::Xsd::Spa::Svg::Geometry::Box.new(0, 0, 100, 50)

      expect { renderer.render({}, box) }.to raise_error(NotImplementedError,
                                                         /must implement #render/)
    end
  end

  describe "#slugify" do
    it "converts CamelCase to kebab-case" do
      expect(renderer.send(:slugify, "PersonType")).to eq("person-type")
    end

    it "handles consecutive capitals" do
      expect(renderer.send(:slugify, "XMLSchema")).to eq("xml-schema")
    end

    it "handles lowercase names" do
      expect(renderer.send(:slugify, "person")).to eq("person")
    end

    it "removes special characters" do
      expect(renderer.send(:slugify,
                           "Person_Type@123")).to eq("person-type-123")
    end

    it "handles nil input" do
      expect(renderer.send(:slugify, nil)).to eq("")
    end

    it "removes leading and trailing dashes" do
      expect(renderer.send(:slugify, "_Person_")).to eq("person")
    end
  end

  describe "#semantic_uri" do
    it "generates semantic URI for element" do
      uri = renderer.send(:semantic_uri, "element", "PersonType")

      expect(uri).to eq("#/schemas/test_schema/element/person-type")
    end

    it "generates semantic URI for type" do
      uri = renderer.send(:semantic_uri, "type", "AddressType")

      expect(uri).to eq("#/schemas/test_schema/type/address-type")
    end
  end

  describe "protected helper methods" do
    let(:box) { Lutaml::Xsd::Spa::Svg::Geometry::Box.new(10, 20, 100, 50) }

    describe "#create_box" do
      it "creates SVG rectangle with default styling" do
        result = renderer.send(:create_box, box, "blue")

        expect(result).to include("<rect")
        expect(result).to include('x="10.0"')
        expect(result).to include('y="20.0"')
        expect(result).to include('width="100.0"')
        expect(result).to include('height="50.0"')
        expect(result).to include('fill="blue"')
        expect(result).to include("stroke=")
        expect(result).to include("stroke-width=")
        expect(result).to include("rx=")
      end

      it "accepts custom options" do
        result = renderer.send(:create_box, box, "red",
                               stroke: "black",
                               stroke_width: 3,
                               corner_radius: 5)

        expect(result).to include('fill="red"')
        expect(result).to include('stroke="black"')
        expect(result).to include('stroke-width="3"')
        expect(result).to include('rx="5"')
      end

      it "adds filter if provided" do
        result = renderer.send(:create_box, box, "green", filter: "shadow")

        expect(result).to include('filter="url(#shadow)"')
      end
    end

    describe "#create_centered_text" do
      it "creates centered text element" do
        result = renderer.send(:create_centered_text, box, "Test Label")

        expect(result).to include("<text")
        expect(result).to include('x="60.0"')  # center x
        expect(result).to include("Test Label</text>")
        expect(result).to include('text-anchor="middle"')
        expect(result).to include('font-weight="bold"')
      end

      it "accepts custom options" do
        result = renderer.send(:create_centered_text, box, "Custom",
                               fill: "red",
                               font_size: 20,
                               font_weight: "normal",
                               offset_y: 30)

        expect(result).to include('fill="red"')
        expect(result).to include('font-size="20"')
        expect(result).to include('font-weight="normal"')
        expect(result).to include('y="50.0"')  # y + offset_y
      end
    end

    describe "#create_link" do
      it "creates SVG anchor element" do
        result = renderer.send(:create_link, "#/test") do
          "<circle/>"
        end

        expect(result).to include('<a href="#/test">')
        expect(result).to include("<circle/>")
        expect(result).to include("</a>")
      end
    end
  end
end
