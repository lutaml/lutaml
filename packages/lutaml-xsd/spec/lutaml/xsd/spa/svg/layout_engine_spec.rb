# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/spa/svg/layout_engine"
require "lutaml/xsd/spa/svg/style_configuration"
require "lutaml/xsd/spa/svg/geometry/point"
require "lutaml/xsd/spa/svg/geometry/box"

RSpec.describe Lutaml::Xsd::Spa::Svg::LayoutEngine do
  let(:config) { Lutaml::Xsd::Spa::Svg::StyleConfiguration.new({}, {}) }
  let(:layout) { described_class.new(config) }

  describe "#initialize" do
    it "stores the configuration" do
      expect(layout.config).to eq(config)
    end
  end

  describe ".for" do
    it "raises ArgumentError for unknown layout type" do
      allow(config).to receive(:layout_type).and_return("unknown")

      expect { described_class.for(config) }.to raise_error(
        ArgumentError,
        /Unknown layout type: unknown/,
      )
    end
  end

  describe "#calculate" do
    it "raises NotImplementedError for abstract base class" do
      expect { layout.calculate({}, :element) }.to raise_error(
        NotImplementedError,
        /must implement #calculate/,
      )
    end
  end

  describe "protected helper methods" do
    describe "#create_node" do
      let(:component) { { name: "TestType" } }
      let(:position) { Lutaml::Xsd::Spa::Svg::Geometry::Point.new(10, 20) }

      it "creates a layout node with component and box" do
        node = layout.send(:create_node, component, position)

        expect(node).to be_a(Lutaml::Xsd::Spa::Svg::LayoutNode)
        expect(node.component).to eq(component)
        expect(node.box).to be_a(Lutaml::Xsd::Spa::Svg::Geometry::Box)
        expect(node.level).to eq(0)
      end

      it "creates box at correct position with config dimensions" do
        node = layout.send(:create_node, component, position)

        expect(node.box.x).to eq(10.0)
        expect(node.box.y).to eq(20.0)
        expect(node.box.width).to eq(config.dimensions.box_width)
        expect(node.box.height).to eq(config.dimensions.box_height)
      end

      it "accepts custom level parameter" do
        node = layout.send(:create_node, component, position, 3)

        expect(node.level).to eq(3)
      end
    end
  end
end

RSpec.describe Lutaml::Xsd::Spa::Svg::LayoutResult do
  let(:nodes) { [] }
  let(:connections) { [] }
  let(:dimensions) { { width: 800, height: 600 } }
  let(:result) { described_class.new(nodes, connections, dimensions) }

  describe "#initialize" do
    it "stores nodes, connections, and dimensions" do
      expect(result.nodes).to eq(nodes)
      expect(result.connections).to eq(connections)
      expect(result.dimensions).to eq(dimensions)
    end
  end
end

RSpec.describe Lutaml::Xsd::Spa::Svg::LayoutNode do
  let(:component) { { name: "TestType" } }
  let(:box) { Lutaml::Xsd::Spa::Svg::Geometry::Box.new(0, 0, 100, 50) }
  let(:node) { described_class.new(component: component, box: box, level: 2) }

  describe "#initialize" do
    it "stores component, box, and level" do
      expect(node.component).to eq(component)
      expect(node.box).to eq(box)
      expect(node.level).to eq(2)
    end
  end
end

RSpec.describe Lutaml::Xsd::Spa::Svg::LayoutConnection do
  let(:from_node) do
    Lutaml::Xsd::Spa::Svg::LayoutNode.new(
      component: { name: "Parent" },
      box: Lutaml::Xsd::Spa::Svg::Geometry::Box.new(0, 0, 100, 50),
      level: 0,
    )
  end

  let(:to_node) do
    Lutaml::Xsd::Spa::Svg::LayoutNode.new(
      component: { name: "Child" },
      box: Lutaml::Xsd::Spa::Svg::Geometry::Box.new(0, 100, 100, 50),
      level: 1,
    )
  end

  let(:connection) do
    described_class.new(from_node, to_node, :inheritance)
  end

  describe "#initialize" do
    it "stores from_node, to_node, and connector_type" do
      expect(connection.from_node).to eq(from_node)
      expect(connection.to_node).to eq(to_node)
      expect(connection.connector_type).to eq(:inheritance)
    end
  end
end
