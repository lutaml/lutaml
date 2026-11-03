# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/spa/svg/utils/svg_builder"
require "lutaml/xsd/spa/svg/geometry/point"

RSpec.describe Lutaml::Xsd::Spa::Svg::Utils::SvgBuilder do
  describe ".escape_xml" do
    it "escapes HTML/XML special characters" do
      expect(described_class.escape_xml("<tag>")).to eq("&lt;tag&gt;")
      expect(described_class.escape_xml("&")).to eq("&amp;")
      expect(described_class.escape_xml('"quote"')).to eq("&quot;quote&quot;")
    end

    it "converts non-string values to string" do
      expect(described_class.escape_xml(123)).to eq("123")
      expect(described_class.escape_xml(nil)).to eq("")
    end
  end

  describe ".element" do
    it "creates a self-closing element without content" do
      result = described_class.element("circle", cx: 50, cy: 50, r: 10)

      expect(result).to include("<circle")
      expect(result).to include('cx="50"')
      expect(result).to include('cy="50"')
      expect(result).to include('r="10"')
      expect(result).to end_with("/>")
    end

    it "creates an element with text content" do
      result = described_class.element("text", { x: 10, y: 20 }, "Hello")

      expect(result).to include("<text")
      expect(result).to include(">Hello</text>")
    end

    it "creates an element with block content" do
      result = described_class.element("g", id: "group") do
        "nested content"
      end

      expect(result).to include('<g id="group">')
      expect(result).to include("nested content</g>")
    end

    it "escapes attribute values" do
      result = described_class.element("text", class: "red&blue")

      expect(result).to include('class="red&amp;blue"')
    end
  end

  describe ".rect" do
    it "creates a rectangle element" do
      result = described_class.rect(10, 20, 100, 50, fill: "blue")

      expect(result).to include("<rect")
      expect(result).to include('x="10"')
      expect(result).to include('y="20"')
      expect(result).to include('width="100"')
      expect(result).to include('height="50"')
      expect(result).to include('fill="blue"')
    end
  end

  describe ".circle" do
    it "creates a circle element" do
      result = described_class.circle(50, 60, 15, fill: "red")

      expect(result).to include("<circle")
      expect(result).to include('cx="50"')
      expect(result).to include('cy="60"')
      expect(result).to include('r="15"')
      expect(result).to include('fill="red"')
    end
  end

  describe ".line" do
    it "creates a line element" do
      result = described_class.line(0, 0, 100, 100, stroke: "black")

      expect(result).to include("<line")
      expect(result).to include('x1="0"')
      expect(result).to include('y1="0"')
      expect(result).to include('x2="100"')
      expect(result).to include('y2="100"')
      expect(result).to include('stroke="black"')
    end
  end

  describe ".text" do
    it "creates a text element with escaped content" do
      result = described_class.text(10, 20, "<script>alert('xss')</script>",
                                    fill: "white")

      expect(result).to include("<text")
      expect(result).to include('x="10"')
      expect(result).to include('y="20"')
      expect(result).to include('fill="white"')
      expect(result).to include("&lt;script&gt;")
      expect(result).not_to include("<script>")
    end
  end

  describe ".group" do
    it "creates a group element with nested content" do
      result = described_class.group(id: "my-group") do
        "<circle/>"
      end

      expect(result).to include('<g id="my-group">')
      expect(result).to include("<circle/>")
      expect(result).to include("</g>")
    end
  end

  describe ".polygon" do
    it "creates a polygon element from points" do
      points = [
        Lutaml::Xsd::Spa::Svg::Geometry::Point.new(0, 0),
        Lutaml::Xsd::Spa::Svg::Geometry::Point.new(10, 0),
        Lutaml::Xsd::Spa::Svg::Geometry::Point.new(5, 10),
      ]

      result = described_class.polygon(points, fill: "green")

      expect(result).to include("<polygon")
      expect(result).to include('points="0.0,0.0 10.0,0.0 5.0,10.0"')
      expect(result).to include('fill="green"')
    end
  end

  describe ".path" do
    it "creates a path element" do
      result = described_class.path("M 10 10 L 20 20", stroke: "blue",
                                                       fill: "none")

      expect(result).to include("<path")
      expect(result).to include('d="M 10 10 L 20 20"')
      expect(result).to include('stroke="blue"')
      expect(result).to include('fill="none"')
    end
  end
end
