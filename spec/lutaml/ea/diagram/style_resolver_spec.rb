# frozen_string_literal: true

require "spec_helper"
require "lutaml/ea/diagram/style_resolver"
require "lutaml/ea/diagram/configuration"

RSpec.describe Lutaml::Ea::Diagram::StyleResolver do
  let(:resolver) { described_class.new }

  describe "#initialize" do
    it "creates configuration instance" do
      expect(resolver.configuration).to be_a(Lutaml::Ea::Diagram::Configuration)
    end

    it "creates style parser instance" do
      expect(resolver.style_parser).to be_a(Lutaml::Ea::Diagram::StyleParser)
    end

    it "accepts custom config path" do
      custom_resolver = described_class.new("custom/path/config.yml")
      expect(custom_resolver.configuration).to be_a(Lutaml::Ea::Diagram::Configuration)
    end
  end

  describe "#resolve_element_style" do
    let(:element) do
      double("Element",
             name: "TestClass",
             package_name: nil,
             stereotype: nil)
    end

    context "without diagram object" do
      it "returns style hash with basic properties" do
        style = resolver.resolve_element_style(element)

        expect(style).to be_a(Hash)
        expect(style).to have_key(:fill)
        expect(style).to have_key(:stroke)
        expect(style).to have_key(:stroke_width)
      end

      it "includes font properties" do
        style = resolver.resolve_element_style(element)

        expect(style).to have_key(:font_family)
        expect(style).to have_key(:font_size)
        expect(style).to have_key(:font_weight)
      end

      it "includes box properties" do
        style = resolver.resolve_element_style(element)

        expect(style).to have_key(:stroke_linecap)
        expect(style).to have_key(:stroke_linejoin)
        expect(style).to have_key(:corner_radius)
      end

      it "compacts nil values" do
        style = resolver.resolve_element_style(element)

        expect(style.values).not_to include(nil)
      end
    end

    context "with diagram object containing EA style" do
      let(:diagram_object) do
        double("DiagramObject",
               style: "BCol=16764159;LCol=0;LWth=2;")
      end

      it "merges EA style with configuration defaults" do
        style = resolver.resolve_element_style(element, diagram_object)

        expect(style).to have_key(:fill)
        expect(style).to have_key(:stroke)
      end

      it "gives priority to EA colors over config" do
        style = resolver.resolve_element_style(element, diagram_object)

        # Should have colors from EA data
        expect(style[:fill]).not_to be_nil
        expect(style[:stroke]).not_to be_nil
      end

      it "includes EA line width" do
        style = resolver.resolve_element_style(element, diagram_object)

        expect(style[:stroke_width]).to eq(2)
      end
    end

    context "with element having stereotype" do
      let(:stereotyped_element) do
        double("Element",
               name: "MyType",
               package_name: nil,
               stereotype: ["DataType"])
      end

      it "applies stereotype-specific fill color" do
        style = resolver.resolve_element_style(stereotyped_element)

        expect(style[:fill]).to eq("#FFCCFF")
      end
    end

    context "with element in specific package" do
      let(:packaged_element) do
        double("Element",
               name: "Feature",
               package_name: "CityGML::Core",
               stereotype: nil)
      end

      it "applies package-specific styles when configured" do
        # This depends on configuration having package rules
        style = resolver.resolve_element_style(packaged_element)

        expect(style).to be_a(Hash)
      end
    end
  end

  describe "#resolve_connector_style" do
    context "with generalization connector" do
      let(:connector) do
        double("Generalization",
               class: double(name: "Lutaml::Uml::Generalization"))
      end

      it "returns generalization style" do
        style = resolver.resolve_connector_style(connector)

        expect(style).to have_key(:arrow_type)
        expect(style[:arrow_type]).to eq("hollow_triangle")
      end

      it "includes line properties" do
        style = resolver.resolve_connector_style(connector)

        expect(style).to have_key(:stroke)
        expect(style).to have_key(:stroke_width)
      end

      it "sets fill to none" do
        style = resolver.resolve_connector_style(connector)

        expect(style[:fill]).to eq("none")
      end
    end

    context "with association connector" do
      let(:connector) do
        double("Association",
               class: double(name: "Lutaml::Uml::Association"),
               member_end: [])
      end

      it "returns association style" do
        style = resolver.resolve_connector_style(connector)

        expect(style).to have_key(:arrow_type)
        expect(style[:arrow_type]).to eq("open_arrow")
      end
    end

    context "with diagram link containing EA style" do
      let(:connector) do
        double("Association",
               class: double(name: "Lutaml::Uml::Association"),
               member_end: [])
      end

      let(:diagram_link) do
        double("DiagramLink",
               style: "LCol=255;LWth=3;LStyle=1;")
      end

      it "merges EA style with defaults" do
        style = resolver.resolve_connector_style(connector, diagram_link)

        expect(style[:stroke_width]).to eq(3)
        expect(style[:stroke_dasharray]).to eq("5,5")
      end
    end

    context "with nil connector" do
      it "defaults to association type" do
        style = resolver.resolve_connector_style(nil)

        expect(style).to be_a(Hash)
        expect(style).to have_key(:arrow_type)
      end
    end
  end

  describe "#resolve_fill_color" do
    let(:element) do
      double("Element",
             name: "TestClass",
             package_name: nil,
             stereotype: nil)
    end

    it "returns configuration fill color" do
      color = resolver.resolve_fill_color(element)

      expect(color).to be_a(String)
      expect(color).to match(/^#[0-9A-F]{6}$/i)
    end

    context "with EA data" do
      let(:diagram_object) do
        double("DiagramObject",
               style: "BCol=16764159;")
      end

      it "prioritizes EA fill color over config" do
        color = resolver.resolve_fill_color(element, diagram_object)

        expect(color).to be_a(String)
        expect(color).to match(/^#[0-9A-F]{6}$/i)
      end
    end

    context "with nil diagram object" do
      it "falls back to configuration" do
        color = resolver.resolve_fill_color(element, nil)

        expect(color).not_to be_nil
      end
    end
  end

  describe "#resolve_stroke_color" do
    let(:element) do
      double("Element",
             name: "TestClass",
             package_name: nil,
             stereotype: nil)
    end

    it "returns configuration stroke color" do
      color = resolver.resolve_stroke_color(element)

      expect(color).to be_a(String)
      expect(color).to match(/^#[0-9A-F]{6}$/i)
    end

    context "with EA data" do
      let(:diagram_object) do
        double("DiagramObject",
               style: "LCol=255;")
      end

      it "prioritizes EA stroke color over config" do
        color = resolver.resolve_stroke_color(element, diagram_object)

        expect(color).to be_a(String)
      end
    end
  end

  describe "#resolve_font" do
    let(:element) do
      double("Element",
             name: "TestClass",
             package_name: nil,
             stereotype: nil)
    end

    it "returns font properties hash" do
      font = resolver.resolve_font(element)

      expect(font).to be_a(Hash)
      expect(font).to have_key(:family)
      expect(font).to have_key(:size)
    end

    it "defaults to class_name context" do
      font = resolver.resolve_font(element)

      expect(font[:weight]).to eq(700) # Bold for class names
    end

    it "accepts different context types" do
      attribute_font = resolver.resolve_font(element, :attribute)
      operation_font = resolver.resolve_font(element, :operation)
      stereotype_font = resolver.resolve_font(element, :stereotype)

      expect(attribute_font).to be_a(Hash)
      expect(operation_font).to be_a(Hash)
      expect(stereotype_font).to be_a(Hash)
    end

    it "compacts nil values" do
      font = resolver.resolve_font(element)

      expect(font.values).not_to include(nil)
    end
  end

  describe "private methods" do
    describe "#parse_diagram_object_style" do
      it "parses BCol (fill color)" do
        style_string = "BCol=16764159;"
        result = resolver.send(:parse_diagram_object_style, style_string)

        expect(result).to have_key(:fill)
        expect(result[:fill]).to match(/^#[0-9A-F]{6}$/i)
      end

      it "parses LCol (stroke color)" do
        style_string = "LCol=255;"
        result = resolver.send(:parse_diagram_object_style, style_string)

        expect(result).to have_key(:stroke)
        expect(result[:stroke]).to match(/^#[0-9A-F]{6}$/i)
      end

      it "parses LWth (line width)" do
        style_string = "LWth=3;"
        result = resolver.send(:parse_diagram_object_style, style_string)

        expect(result[:stroke_width]).to eq(3)
      end

      it "parses BFol (bold font)" do
        bold_style = "BFol=1;"
        normal_style = "BFol=0;"

        bold_result = resolver.send(:parse_diagram_object_style, bold_style)
        normal_result = resolver.send(:parse_diagram_object_style, normal_style)

        expect(bold_result[:font_weight]).to eq(700)
        expect(normal_result[:font_weight]).to eq(400)
      end

      it "parses IFol (italic font)" do
        italic_style = "IFol=1;"
        normal_style = "IFol=0;"

        italic_result = resolver.send(:parse_diagram_object_style, italic_style)
        normal_result = resolver.send(:parse_diagram_object_style, normal_style)

        expect(italic_result[:font_style]).to eq("italic")
        expect(normal_result[:font_style]).to eq("normal")
      end

      it "parses multiple properties" do
        style_string = "BCol=16764159;LCol=255;LWth=2;BFol=1;IFol=1;"
        result = resolver.send(:parse_diagram_object_style, style_string)

        expect(result).to have_key(:fill)
        expect(result).to have_key(:stroke)
        expect(result[:stroke_width]).to eq(2)
        expect(result[:font_weight]).to eq(700)
        expect(result[:font_style]).to eq("italic")
      end

      it "handles nil style string" do
        result = resolver.send(:parse_diagram_object_style, nil)

        expect(result).to eq({})
      end

      it "handles empty style string" do
        result = resolver.send(:parse_diagram_object_style, "")

        expect(result).to eq({})
      end

      it "ignores unknown properties" do
        style_string = "UNKNOWN=123;BCol=16764159;"
        result = resolver.send(:parse_diagram_object_style, style_string)

        expect(result).to have_key(:fill)
        expect(result).not_to have_key(:unknown)
      end

      it "handles malformed key-value pairs" do
        style_string = "BCol=;=123;BCol=16764159;"
        result = resolver.send(:parse_diagram_object_style, style_string)

        expect(result).to have_key(:fill)
      end
    end

    describe "#parse_diagram_link_style" do
      it "parses LCol (line color)" do
        style_string = "LCol=255;"
        result = resolver.send(:parse_diagram_link_style, style_string)

        expect(result).to have_key(:stroke)
        expect(result[:stroke]).to match(/^#[0-9A-F]{6}$/i)
      end

      it "parses LWth (line width)" do
        style_string = "LWth=3;"
        result = resolver.send(:parse_diagram_link_style, style_string)

        expect(result[:stroke_width]).to eq(3)
      end

      it "parses LStyle for dashed line" do
        dash_style = "LStyle=1;"
        result = resolver.send(:parse_diagram_link_style, dash_style)

        expect(result[:stroke_dasharray]).to eq("5,5")
      end

      it "parses LStyle for dotted line" do
        dot_style = "LStyle=2;"
        result = resolver.send(:parse_diagram_link_style, dot_style)

        expect(result[:stroke_dasharray]).to eq("2,2")
      end

      it "handles nil style string" do
        result = resolver.send(:parse_diagram_link_style, nil)

        expect(result).to eq({})
      end

      it "handles solid line style (LStyle=0)" do
        solid_style = "LStyle=0;"
        result = resolver.send(:parse_diagram_link_style, solid_style)

        # LStyle=0 should not set stroke_dasharray
        expect(result).not_to have_key(:stroke_dasharray)
      end
    end

    describe "#determine_connector_type" do
      it "returns 'generalization' for Generalization class" do
        connector = double("Connector", class: double(name: "Lutaml::Uml::Generalization"))
        type = resolver.send(:determine_connector_type, connector)

        expect(type).to eq("generalization")
      end

      it "returns 'association' for Association class" do
        connector = double("Connector",
                           class: double(name: "Lutaml::Uml::Association"),
                           member_end: [])
        type = resolver.send(:determine_connector_type, connector)

        expect(type).to eq("association")
      end

      it "returns 'dependency' for Dependency class" do
        connector = double("Connector", class: double(name: "Lutaml::Uml::Dependency"))
        type = resolver.send(:determine_connector_type, connector)

        expect(type).to eq("dependency")
      end

      it "returns 'realization' for Realization class" do
        connector = double("Connector", class: double(name: "Lutaml::Uml::Realization"))
        type = resolver.send(:determine_connector_type, connector)

        expect(type).to eq("realization")
      end

      it "defaults to 'association' for unknown types" do
        connector = double("Connector", class: double(name: "Unknown::Type"))
        type = resolver.send(:determine_connector_type, connector)

        expect(type).to eq("association")
      end

      it "returns 'association' for nil connector" do
        type = resolver.send(:determine_connector_type, nil)

        expect(type).to eq("association")
      end
    end

    describe "#determine_association_type" do
      it "returns 'aggregation' for shared aggregation" do
        end_point = double("MemberEnd", aggregation: "shared")
        connector = double("Association", member_end: [end_point])

        type = resolver.send(:determine_association_type, connector)

        expect(type).to eq("aggregation")
      end

      it "returns 'composition' for composite aggregation" do
        end_point = double("MemberEnd", aggregation: "composite")
        connector = double("Association", member_end: [end_point])

        type = resolver.send(:determine_association_type, connector)

        expect(type).to eq("composition")
      end

      it "handles case-insensitive aggregation values" do
        end_point = double("MemberEnd", aggregation: "SHARED")
        connector = double("Association", member_end: [end_point])

        type = resolver.send(:determine_association_type, connector)

        expect(type).to eq("aggregation")
      end

      it "returns 'association' for no aggregation" do
        end_point = double("MemberEnd", aggregation: nil)
        connector = double("Association", member_end: [end_point])

        type = resolver.send(:determine_association_type, connector)

        expect(type).to eq("association")
      end

      it "returns 'association' when member_end not available" do
        connector = double("Association")

        type = resolver.send(:determine_association_type, connector)

        expect(type).to eq("association")
      end

      it "returns 'association' for empty member_end" do
        connector = double("Association", member_end: [])

        type = resolver.send(:determine_association_type, connector)

        expect(type).to eq("association")
      end

      it "checks all member ends for aggregation" do
        normal_end = double("MemberEnd", aggregation: nil)
        composite_end = double("MemberEnd", aggregation: "composite")
        connector = double("Association",
                           member_end: [normal_end, composite_end])

        type = resolver.send(:determine_association_type, connector)

        expect(type).to eq("composition")
      end
    end
  end
end