# frozen_string_literal: true

require "spec_helper"
require "lutaml/ea/diagram/element_renderers/package_renderer"
require "lutaml/ea/diagram/style_resolver"

RSpec.describe Lutaml::Ea::Diagram::ElementRenderers::PackageRenderer do
  let(:style_resolver) { Lutaml::Ea::Diagram::StyleResolver.new }
  let(:element_data) do
    {
      id: "package-1",
      type: "package",
      name: "CoreModel",
      x: 100,
      y: 50,
      width: 120,
      height: 80,
      element: double("Element",
                      name: "CoreModel",
                      package_name: nil,
                      stereotype: nil),
      diagram_object: nil,
    }
  end
  let(:renderer) { described_class.new(element_data, style_resolver) }

  describe "inheritance" do
    it "inherits from BaseRenderer" do
      expect(described_class).to be < Lutaml::Ea::Diagram::ElementRenderers::BaseRenderer
    end
  end

  describe "#render_shape" do
    let(:style) do
      {
        fill: "#E0E0E0",
        stroke: "#000000",
        stroke_width: 2,
      }
    end

    it "renders package body as polygon" do
      shape = renderer.send(:render_shape, style)

      expect(shape).to include("<polygon")
      expect(shape).to include("lutaml-diagram-package-shape")
    end

    it "renders package tab as separate polygon" do
      shape = renderer.send(:render_shape, style)

      expect(shape).to include("lutaml-diagram-package-tab")
    end

    it "applies fill color to both body and tab" do
      shape = renderer.send(:render_shape, style)

      # Should appear twice, once for body and once for tab
      expect(shape.scan('fill="#E0E0E0"').count).to eq(2)
    end

    it "applies stroke color to both body and tab" do
      shape = renderer.send(:render_shape, style)

      # Should appear twice
      expect(shape.scan('stroke="#000000"').count).to eq(2)
    end

    it "applies stroke width from style" do
      shape = renderer.send(:render_shape, style)

      expect(shape).to include('stroke-width="2"')
    end

    it "defaults stroke width to 2 when not in style" do
      shape = renderer.send(:render_shape, {})

      expect(shape).to include('stroke-width="2"')
    end

    it "positions body below tab" do
      shape = renderer.send(:render_shape, style)

      # Tab height is 20, so body starts at y + 20 = 50 + 20 = 70
      expect(shape).to include("100,70")
    end

    it "positions tab at top of package" do
      shape = renderer.send(:render_shape, style)

      # Tab should be positioned with correct coordinates
      # Tab goes from (x+10, y+tab_height) to (x+50, y+tab_height) to
      # (x+50, y) to (x+10, y)
      # = (110, 70) to (150, 70) to (150, 50) to (110, 50)
      expect(shape).to include("110,70 150,70 150,50 110,50")
    end

    it "uses element dimensions for body" do
      shape = renderer.send(:render_shape, style)

      # Body width should match element width (120)
      # Body should go from x=100 to x=220 (100+120)
      expect(shape).to include("220,70") # Upper right corner of body
    end

    it "handles missing style gracefully" do
      shape = renderer.send(:render_shape, {})

      expect(shape).to include("<polygon")
    end
  end

  describe "#render_label" do
    let(:style) do
      {
        font_family: "Arial, sans-serif",
        font_size: 9,
        font_weight: "bold",
        text_color: "#000000",
      }
    end

    it "renders package name in tab area" do
      label = renderer.send(:render_label, style)

      expect(label).to include("CoreModel")
      expect(label).to include("<text")
    end

    it "centers text in tab horizontally" do
      label = renderer.send(:render_label, style)

      # Tab center: x + 30 = 100 + 30 = 130
      expect(label).to include('x="130"')
    end

    it "centers text in tab vertically" do
      label = renderer.send(:render_label, style)

      # Tab height / 2 + 5 = 20 / 2 + 5 = 15
      # y + 15 = 50 + 15 = 65
      expect(label).to include('y="65"')
    end

    it "applies text-anchor middle" do
      label = renderer.send(:render_label, style)

      expect(label).to include('text-anchor="middle"')
    end

    it "applies dominant-baseline middle" do
      label = renderer.send(:render_label, style)

      expect(label).to include('dominant-baseline="middle"')
    end

    it "applies font family from style" do
      label = renderer.send(:render_label, style)

      expect(label).to include('font-family="Arial, sans-serif"')
    end

    it "applies font size from style" do
      label = renderer.send(:render_label, style)

      expect(label).to include('font-size="9"')
    end

    it "applies font weight from style" do
      label = renderer.send(:render_label, style)

      expect(label).to include('font-weight="bold"')
    end

    it "defaults font weight to bold when not in style" do
      style.delete(:font_weight)
      label = renderer.send(:render_label, style)

      expect(label).to include('font-weight="bold"')
    end

    it "applies text color from style" do
      label = renderer.send(:render_label, style)

      expect(label).to include('fill="#000000"')
    end

    it "defaults text color to black when not in style" do
      style.delete(:text_color)
      label = renderer.send(:render_label, style)

      expect(label).to include('fill="#000000"')
    end

    it "includes lutaml-diagram-package-name class" do
      label = renderer.send(:render_label, style)

      expect(label).to include('class="lutaml-diagram-package-name"')
    end

    it "escapes package name" do
      element_data[:name] = "Core<Model> & \"Data\""
      label = renderer.send(:render_label, style)

      expect(label).to include("Core&lt;Model&gt; &amp; &quot;Data&quot;")
    end

    it "handles missing dimensions gracefully" do
      element_data.delete(:width)
      element_data.delete(:height)
      label = renderer.send(:render_label, style)

      expect(label).to include("<text")
    end
  end
end