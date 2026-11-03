# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/spa/svg/connector_renderer"
require "lutaml/xsd/spa/svg/style_configuration"
require "lutaml/xsd/spa/svg/geometry/point"

RSpec.describe Lutaml::Xsd::Spa::Svg::ConnectorRenderer do
  let(:config) { Lutaml::Xsd::Spa::Svg::StyleConfiguration.new({}, {}) }
  let(:renderer) { described_class.new(config, :inheritance) }

  describe "#initialize" do
    it "stores config and connector style" do
      expect(renderer.config).to eq(config)
      expect(renderer.style).to be_a(Lutaml::Xsd::Spa::Svg::Config::ConnectorStyle)
      expect(renderer.style.stroke_width).to eq(2)
      expect(renderer.style.arrow_size).to eq(8)
    end
  end

  describe "#render" do
    it "raises NotImplementedError for abstract base class" do
      from_point = Lutaml::Xsd::Spa::Svg::Geometry::Point.new(0, 0)
      to_point = Lutaml::Xsd::Spa::Svg::Geometry::Point.new(100, 100)

      expect { renderer.render(from_point, to_point) }.to raise_error(
        NotImplementedError,
        /must implement #render/,
      )
    end
  end

  describe "protected helper methods" do
    let(:from_point) { Lutaml::Xsd::Spa::Svg::Geometry::Point.new(10, 20) }
    let(:to_point) { Lutaml::Xsd::Spa::Svg::Geometry::Point.new(50, 80) }

    describe "#create_line" do
      it "creates SVG line with default styling" do
        result = renderer.send(:create_line, from_point, to_point)

        expect(result).to include("<line")
        expect(result).to include('x1="10.0"')
        expect(result).to include('y1="20.0"')
        expect(result).to include('x2="50.0"')
        expect(result).to include('y2="80.0"')
        expect(result).to include("stroke-width=")
      end

      it "accepts custom stroke options" do
        result = renderer.send(:create_line, from_point, to_point,
                               stroke: "red",
                               stroke_width: 3)

        expect(result).to include('stroke="red"')
        expect(result).to include('stroke-width="3"')
      end

      it "adds dash pattern when provided" do
        result = renderer.send(:create_line, from_point, to_point,
                               dash_pattern: "5,5")

        expect(result).to include('stroke-dasharray="5,5"')
      end

      it "omits dash pattern when not provided" do
        result = renderer.send(:create_line, from_point, to_point)

        expect(result).not_to include("stroke-dasharray")
      end
    end

    describe "#create_arrow_down" do
      let(:point) { Lutaml::Xsd::Spa::Svg::Geometry::Point.new(50, 50) }

      it "creates downward-pointing arrow polygon" do
        result = renderer.send(:create_arrow_down, point)

        expect(result).to include("<polygon")
        expect(result).to include("points=")
      end

      it "creates arrow with correct points" do
        result = renderer.send(:create_arrow_down, point, size: 5)

        # Arrow should point down: apex at point, base points above
        expect(result).to include("50.0,50.0") # apex
        expect(result).to include("45.0,43.75")  # left base
        expect(result).to include("55.0,43.75")  # right base
      end

      it "accepts custom fill and stroke" do
        result = renderer.send(:create_arrow_down, point,
                               fill: "blue",
                               stroke: "black",
                               stroke_width: 2)

        expect(result).to include('fill="blue"')
        expect(result).to include('stroke="black"')
        expect(result).to include('stroke-width="2"')
      end
    end

    describe "#create_arrow_up" do
      let(:point) { Lutaml::Xsd::Spa::Svg::Geometry::Point.new(50, 50) }

      it "creates upward-pointing arrow polygon" do
        result = renderer.send(:create_arrow_up, point)

        expect(result).to include("<polygon")
        expect(result).to include("points=")
      end

      it "creates arrow with correct points" do
        result = renderer.send(:create_arrow_up, point, size: 5)

        # Arrow should point up: apex at point, base points below
        expect(result).to include("50.0,50.0") # apex
        expect(result).to include("45.0,56.25")  # left base
        expect(result).to include("55.0,56.25")  # right base
      end
    end

    describe "#direction" do
      it "returns :down when moving predominantly downward" do
        from = Lutaml::Xsd::Spa::Svg::Geometry::Point.new(50, 10)
        to = Lutaml::Xsd::Spa::Svg::Geometry::Point.new(55, 100)

        expect(renderer.send(:direction, from, to)).to eq(:down)
      end

      it "returns :up when moving predominantly upward" do
        from = Lutaml::Xsd::Spa::Svg::Geometry::Point.new(50, 100)
        to = Lutaml::Xsd::Spa::Svg::Geometry::Point.new(55, 10)

        expect(renderer.send(:direction, from, to)).to eq(:up)
      end

      it "returns :right when moving predominantly rightward" do
        from = Lutaml::Xsd::Spa::Svg::Geometry::Point.new(10, 50)
        to = Lutaml::Xsd::Spa::Svg::Geometry::Point.new(100, 55)

        expect(renderer.send(:direction, from, to)).to eq(:right)
      end

      it "returns :left when moving predominantly leftward" do
        from = Lutaml::Xsd::Spa::Svg::Geometry::Point.new(100, 50)
        to = Lutaml::Xsd::Spa::Svg::Geometry::Point.new(10, 55)

        expect(renderer.send(:direction, from, to)).to eq(:left)
      end
    end
  end
end
