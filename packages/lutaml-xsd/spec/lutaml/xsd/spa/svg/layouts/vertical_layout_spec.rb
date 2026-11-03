# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/spa/svg/style_configuration"
require "lutaml/xsd/spa/svg/layouts/vertical_layout"

RSpec.describe Lutaml::Xsd::Spa::Svg::Layouts::VerticalLayout do
  let(:config) { Lutaml::Xsd::Spa::Svg::StyleConfiguration.load }
  let(:layout) { described_class.new(config) }

  describe "#calculate" do
    context "with simple element data" do
      let(:component_data) do
        {
          "name" => "PersonElement",
          "kind" => "element",
        }
      end

      it "returns a LayoutResult" do
        result = layout.calculate(component_data, :element)

        expect(result).to be_a(Lutaml::Xsd::Spa::Svg::LayoutResult)
      end

      it "creates a node for the main component" do
        result = layout.calculate(component_data, :element)

        expect(result.nodes.length).to eq(1)
        expect(result.nodes.first.component["name"]).to eq("PersonElement")
      end

      it "positions the node at the start coordinates" do
        result = layout.calculate(component_data, :element)

        node = result.nodes.first
        expect(node.box.x).to eq(20)
        expect(node.box.y).to eq(20)
      end

      it "calculates correct dimensions" do
        result = layout.calculate(component_data, :element)

        expect(result.dimensions.width).to be > 0
        expect(result.dimensions.height).to be > 0
      end
    end

    context "with element and type" do
      let(:component_data) do
        {
          "name" => "PersonElement",
          "kind" => "element",
          "type" => "PersonType",
        }
      end

      it "creates nodes for both element and type" do
        result = layout.calculate(component_data, :element)

        expect(result.nodes.length).to eq(2)
        expect(result.nodes[0].component["name"]).to eq("PersonElement")
        expect(result.nodes[1].component["name"]).to eq("PersonType")
      end

      it "creates a containment connection" do
        result = layout.calculate(component_data, :element)

        expect(result.connections.length).to eq(1)
        expect(result.connections.first.connector_type).to eq("containment")
      end

      it "positions type below element" do
        result = layout.calculate(component_data, :element)

        element_y = result.nodes[0].box.y
        type_y = result.nodes[1].box.y
        expect(type_y).to be > element_y
      end
    end

    context "with attributes" do
      let(:component_data) do
        {
          "name" => "PersonElement",
          "kind" => "element",
          "attributes" => [
            { "name" => "id" },
            { "name" => "name" },
          ],
        }
      end

      it "creates nodes for attributes" do
        result = layout.calculate(component_data, :element)

        expect(result.nodes.length).to eq(3)
        expect(result.nodes[1].component["name"]).to eq("id")
        expect(result.nodes[2].component["name"]).to eq("name")
      end

      it "indents attribute nodes" do
        result = layout.calculate(component_data, :element)

        main_x = result.nodes[0].box.x
        attr_x = result.nodes[1].box.x
        expect(attr_x).to be > main_x
      end
    end
  end
end
