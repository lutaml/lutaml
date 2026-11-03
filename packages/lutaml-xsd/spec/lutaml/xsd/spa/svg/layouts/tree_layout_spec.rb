# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/spa/svg/style_configuration"
require "lutaml/xsd/spa/svg/layouts/tree_layout"

RSpec.describe Lutaml::Xsd::Spa::Svg::Layouts::TreeLayout do
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
    end

    context "with element and type" do
      let(:component_data) do
        {
          "name" => "PersonElement",
          "kind" => "element",
          "type" => "PersonType",
        }
      end

      it "creates nodes in hierarchical structure" do
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

      it "positions child below and indented from parent" do
        result = layout.calculate(component_data, :element)

        parent_node = result.nodes[0]
        child_node = result.nodes[1]

        expect(child_node.box.x).to be > parent_node.box.x
        expect(child_node.box.y).to be > parent_node.box.y
      end
    end

    context "with inheritance" do
      let(:component_data) do
        {
          "name" => "EmployeeType",
          "kind" => "type",
          "base_type" => "PersonType",
        }
      end

      it "creates inheritance connection" do
        result = layout.calculate(component_data, :type)

        expect(result.connections.length).to eq(1)
        expect(result.connections.first.connector_type).to eq("inheritance")
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

      it "creates nodes for all attributes" do
        result = layout.calculate(component_data, :element)

        expect(result.nodes.length).to eq(3)
        expect(result.nodes[1].component["name"]).to eq("id")
        expect(result.nodes[2].component["name"]).to eq("name")
      end

      it "connects attributes to parent with containment" do
        result = layout.calculate(component_data, :element)

        expect(result.connections.length).to eq(2)
        expect(result.connections.all? do |conn|
          conn.connector_type == "containment"
        end).to be true
      end
    end

    context "with content model" do
      let(:component_data) do
        {
          "name" => "PersonElement",
          "kind" => "element",
          "content_model" => {
            "elements" => [
              { "name" => "firstName" },
              { "name" => "lastName" },
            ],
          },
        }
      end

      it "creates nodes for content model elements" do
        result = layout.calculate(component_data, :element)

        expect(result.nodes.length).to eq(3)
        expect(result.nodes[1].component["name"]).to eq("firstName")
        expect(result.nodes[2].component["name"]).to eq("lastName")
      end
    end

    context "with complex hierarchy" do
      let(:component_data) do
        {
          "name" => "PersonElement",
          "kind" => "element",
          "type" => "PersonType",
          "attributes" => [
            { "name" => "id" },
          ],
        }
      end

      it "creates correct hierarchy with multiple levels" do
        result = layout.calculate(component_data, :element)

        expect(result.nodes.length).to eq(3)
        expect(result.connections.length).to eq(2)
      end

      it "assigns correct levels to nodes" do
        result = layout.calculate(component_data, :element)

        expect(result.nodes[0].level).to eq(0)
        expect(result.nodes[1].level).to eq(1)
        expect(result.nodes[2].level).to eq(1)
      end
    end
  end
end
