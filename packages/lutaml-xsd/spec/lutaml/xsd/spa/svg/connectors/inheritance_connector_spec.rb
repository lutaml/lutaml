# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/spa/svg/style_configuration"
require "lutaml/xsd/spa/svg/connectors/inheritance_connector"

RSpec.describe Lutaml::Xsd::Spa::Svg::Connectors::InheritanceConnector do
  let(:config) { Lutaml::Xsd::Spa::Svg::StyleConfiguration.load }
  let(:connector) { described_class.new(config) }
  let(:from_point) do
    Lutaml::Xsd::Spa::Svg::Geometry::Point.new(50, 50)
  end
  let(:to_point) do
    Lutaml::Xsd::Spa::Svg::Geometry::Point.new(50, 100)
  end

  describe "#initialize" do
    it "sets connector type to inheritance" do
      style = connector.style
      expected_style = config.connectors.for_type("inheritance")

      expect(style.type).to eq(expected_style.type)
      expect(style.stroke_width).to eq(expected_style.stroke_width)
      expect(style.arrow_size).to eq(expected_style.arrow_size)
    end
  end

  describe "#render" do
    it "renders a line and hollow triangle" do
      svg = connector.render(from_point, to_point)

      expect(svg).to include("<line")
      expect(svg).to include("<polygon")
      expect(svg).to include('fill="white"')
    end

    it "uses inheritance connector style from config" do
      svg = connector.render(from_point, to_point)

      stroke_width = config.connectors.for_type("inheritance").stroke_width
      expect(svg).to include("stroke-width=\"#{stroke_width}\"")
    end

    it "connects from source to target point" do
      svg = connector.render(from_point, to_point)

      expect(svg).to include("x1=\"#{from_point.x}\"")
      expect(svg).to include("y1=\"#{from_point.y}\"")
      expect(svg).to include("x2=\"#{to_point.x}\"")
      expect(svg).to include("y2=\"#{to_point.y}\"")
    end

    it "includes border color in the triangle" do
      svg = connector.render(from_point, to_point)

      border_color = config.colors.ui.border
      expect(svg).to include("stroke=\"#{border_color}\"")
    end
  end
end
