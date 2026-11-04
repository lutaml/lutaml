# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/spa/svg/style_configuration"
require "lutaml/xsd/spa/svg/renderers/element_renderer"

RSpec.describe Lutaml::Xsd::Spa::Svg::Renderers::ElementRenderer do
  let(:config) { Lutaml::Xsd::Spa::Svg::StyleConfiguration.load }
  let(:schema_name) { "test_schema" }
  let(:renderer) { described_class.new(config, schema_name) }
  let(:box) do
    Lutaml::Xsd::Spa::Svg::Geometry::Box.new(10, 20, 150, 40)
  end

  describe "#render" do
    context "with simple element" do
      let(:component_data) do
        {
          "name" => "PersonElement",
          "kind" => "element",
        }
      end

      it "renders SVG markup" do
        svg = renderer.render(component_data, box)

        expect(svg).to include("<g")
        expect(svg).to include("element-box")
      end

      it "includes a rectangle box" do
        svg = renderer.render(component_data, box)

        expect(svg).to include("<rect")
        expect(svg).to include("x=\"#{box.x}\"")
        expect(svg).to include("y=\"#{box.y}\"")
      end

      it "includes centered text with element name" do
        svg = renderer.render(component_data, box)

        expect(svg).to include("<text")
        expect(svg).to include("PersonElement")
      end

      it "uses element color from config" do
        svg = renderer.render(component_data, box)

        if config.effects.gradient_enabled?
          expect(svg).to include("url(#elementGradient)")
        else
          expect(svg).to include(config.colors.element.base)
        end
      end
    end

    context "with clickable element" do
      let(:component_data) do
        {
          "name" => "PersonElement",
          "kind" => "element",
        }
      end

      it "wraps content in a link when clickable" do
        allow(config.component_rule("element")).to receive(:clickable)
          .and_return(true)

        svg = renderer.render(component_data, box)

        expect(svg).to include("<a")
        expect(svg).to include("href=")
      end

      it "generates semantic URI for the link" do
        allow(config.component_rule("element")).to receive(:clickable)
          .and_return(true)

        svg = renderer.render(component_data, box)

        expect(svg).to include(
          "#/schemas/#{schema_name}/elements/person-element",
        )
      end
    end

    context "with abstract element" do
      let(:component_data) do
        {
          "name" => "AbstractElement",
          "kind" => "element",
          "abstract" => true,
        }
      end

      it "renders abstract indicator" do
        svg = renderer.render(component_data, box)

        indicator = config.indicator_rule("abstract")
        expect(svg).to include(indicator.text) if indicator
      end
    end

    context "with optional element" do
      let(:component_data) do
        {
          "name" => "OptionalElement",
          "kind" => "element",
          "min_occurs" => "0",
        }
      end

      it "renders optional indicator" do
        svg = renderer.render(component_data, box)

        indicator = config.indicator_rule("optional")
        expect(svg).to include(indicator.text) if indicator
      end
    end

    context "with filter effects" do
      let(:component_data) do
        {
          "name" => "PersonElement",
          "kind" => "element",
        }
      end

      it "applies filter from component rule" do
        rule = config.component_rule("element")
        svg = renderer.render(component_data, box)

        expect(svg).to include("filter=\"url(##{rule.filter})\"") if rule.filter
      end
    end
  end
end
