# frozen_string_literal: true

require "spec_helper"
require "lutaml/ea/diagram/element_renderers/class_renderer"
require "lutaml/ea/diagram/style_resolver"

RSpec.describe Lutaml::Ea::Diagram::ElementRenderers::ClassRenderer do
  let(:style_resolver) { Lutaml::Ea::Diagram::StyleResolver.new }
  let(:element_data) do
    {
      id: "class-1",
      type: "class",
      name: "Person",
      x: 100,
      y: 50,
      width: 120,
      height: 80,
      stereotype: nil,
      attributes: [],
      operations: [],
      element: double("Element",
        name: "Person",
        package_name: nil,
        stereotype: nil
      ),
      diagram_object: nil
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
        stroke_linecap: "round",
        stroke_linejoin: "bevel",
        corner_radius: 0,
        fill_opacity: "1.00",
        stroke_opacity: "1.00"
      }
    end

    it "renders rectangle for class box" do
      shape = renderer.send(:render_shape, style)

      expect(shape).to include("<rect")
      expect(shape).to include("x=\"100\"")
      expect(shape).to include("y=\"50\"")
    end

    it "applies fill color from style" do
      shape = renderer.send(:render_shape, style)

      expect(shape).to include("fill:#E0E0E0")
    end

    it "applies stroke color from style" do
      shape = renderer.send(:render_shape, style)

      expect(shape).to include("stroke:#000000")
    end

    it "applies stroke width from style" do
      shape = renderer.send(:render_shape, style)

      expect(shape).to include("stroke-width:2")
    end

    it "applies corner radius from style" do
      style[:corner_radius] = 5
      shape = renderer.send(:render_shape, style)

      expect(shape).to include("rx=\"5\"")
    end

    it "includes name compartment separator" do
      shape = renderer.send(:render_shape, style)

      # Name compartment at y + 25
      expect(shape).to include("M 100 75")
      expect(shape).to include("L 220 75")
    end

    context "with attributes" do
      before do
        element_data[:attributes] = [
          { name: "name", type: "String", visibility: "private" },
          { name: "age", type: "Integer", visibility: "public" }
        ]
      end

      it "includes attributes compartment separator" do
        shape = renderer.send(:render_shape, style)

        # Attributes height = 2 * 15 + 10 = 40
        # Separator at y + name_height + attributes_height = 50 + 25 + 40 = 115
        expect(shape).to include("M 100 115")
      end

      it "adjusts height to fit attributes" do
        shape = renderer.send(:render_shape, style)

        # Should have height >= name_height(25) + attributes_height(40) + operations_height(0)
        expect(shape).to match(/height="\d+"/)
      end
    end

    context "with operations" do
      before do
        element_data[:operations] = [
          { name: "getName", return_type: "String", visibility: "public" }
        ]
      end

      it "includes operations compartment separator" do
        shape = renderer.send(:render_shape, style)

        # Operations height = 1 * 15 + 10 = 25
        # Should have a separator path
        expect(shape).to include("<path")
      end
    end

    it "uses default values when style properties missing" do
      shape = renderer.send(:render_shape, {})

      expect(shape).to include("<rect")
      expect(shape).to include("fill:#000000") # default
      expect(shape).to include("stroke:#000000") # default
    end
  end

  describe "#render_label" do
    let(:style) do
      {
        font_family: "Arial, sans-serif",
        font_size: 9,
        font_weight: 700,
        font_style: "normal"
      }
    end

    it "renders class name centered in name compartment" do
      label = renderer.send(:render_label, style)

      expect(label).to include("Person")
      expect(label).to include("text-anchor=\"middle\"")
    end

    it "applies font style to class name" do
      label = renderer.send(:render_label, style)

      expect(label).to include("font-family:Arial, sans-serif")
      expect(label).to include("font-weight:700")
      expect(label).to include("font-style:normal")
    end

    it "includes lutaml-diagram-class-name class" do
      label = renderer.send(:render_label, style)

      expect(label).to include("lutaml-diagram-class-name")
    end

    context "with stereotype" do
      before do
        element_data[:stereotype] = "DataType"
      end

      it "renders stereotype above class name" do
        label = renderer.send(:render_label, style)

        expect(label).to include("«DataType»")
      end

      it "includes lutaml-diagram-class-stereotype class" do
        label = renderer.send(:render_label, style)

        expect(label).to include("lutaml-diagram-class-stereotype")
      end

      it "adjusts class name position when stereotype present" do
        label = renderer.send(:render_label, style)

        # Should have two text elements
        expect(label.scan(/<text/).size).to eq(2)
      end
    end

    context "with attributes" do
      before do
        element_data[:attributes] = [
          { name: "name", type: "String", visibility: "private" },
          { name: "age", type: "Integer", visibility: "public" }
        ]
      end

      it "renders all attributes" do
        label = renderer.send(:render_label, style)

        expect(label).to include("-name: String")
        expect(label).to include("+age: Integer")
      end

      it "includes lutaml-diagram-class-attribute class" do
        label = renderer.send(:render_label, style)

        expect(label).to include("lutaml-diagram-class-attribute")
      end

      it "left-aligns attributes" do
        label = renderer.send(:render_label, style)

        expect(label).to include("text-anchor=\"start\"")
      end

      it "positions attributes below name compartment" do
        label = renderer.send(:render_label, style)

        # First attribute should be at y + name_height + 15
        # = 50 + 25 + 15 = 90
        expect(label).to match(/y\=\"90/)
      end
    end

    context "with operations" do
      before do
        element_data[:operations] = [
          { name: "getName", return_type: "String", visibility: "public", parameters: [] },
          { name: "setAge", return_type: nil, visibility: "public",
            parameters: [{ name: "value", type: "Integer" }] }
        ]
      end

      it "renders all operations" do
        label = renderer.send(:render_label, style)

        expect(label).to include("+getName(): String")
        expect(label).to include("+setAge(value: Integer)")
      end

      it "includes lutaml-diagram-class-operation class" do
        label = renderer.send(:render_label, style)

        expect(label).to include("lutaml-diagram-class-operation")
      end

      it "left-aligns operations" do
        label = renderer.send(:render_label, style)

        expect(label).to include("text-anchor=\"start\"")
      end
    end

    it "wraps all text in styled group" do
      label = renderer.send(:render_label, style)

      expect(label).to start_with("<g style=")
      expect(label).to end_with("</g>")
    end
  end

  describe "private methods" do
    describe "#calculate_attributes_height" do
      it "returns 0 when no attributes" do
        height = renderer.send(:calculate_attributes_height)

        expect(height).to eq(0)
      end

      it "calculates height based on number of attributes" do
        element_data[:attributes] = [{}, {}, {}] # 3 attributes

        height = renderer.send(:calculate_attributes_height)

        expect(height).to eq(55) # 3 * 15 + 10
      end

      it "returns 0 for empty attributes array" do
        element_data[:attributes] = []

        height = renderer.send(:calculate_attributes_height)

        expect(height).to eq(0)
      end
    end

    describe "#calculate_operations_height" do
      it "returns 0 when no operations" do
        height = renderer.send(:calculate_operations_height)

        expect(height).to eq(0)
      end

      it "calculates height based on number of operations" do
        element_data[:operations] = [{}, {}] # 2 operations

        height = renderer.send(:calculate_operations_height)

        expect(height).to eq(40) # 2 * 15 + 10
      end

      it "returns 0 for empty operations array" do
        element_data[:operations] = []

        height = renderer.send(:calculate_operations_height)

        expect(height).to eq(0)
      end
    end

    describe "#format_attribute" do
      it "formats attribute with visibility, name, and type" do
        attr = { name: "id", type: "Integer", visibility: "private" }

        result = renderer.send(:format_attribute, attr)

        expect(result).to eq("-id: Integer")
      end

      it "handles missing type" do
        attr = { name: "name", visibility: "public" }

        result = renderer.send(:format_attribute, attr)

        expect(result).to eq("+name")
      end

      it "handles missing visibility" do
        attr = { name: "value", type: "String" }

        result = renderer.send(:format_attribute, attr)

        expect(result).to eq("value: String")
      end

      it "handles plain string attribute" do
        result = renderer.send(:format_attribute, "name")

        expect(result).to eq("name")
      end
    end

    describe "#format_operation" do
      it "formats operation with visibility, name, parameters, and return type" do
        op = {
          name: "calculate",
          visibility: "public",
          parameters: [{ name: "x", type: "Integer" }],
          return_type: "Boolean"
        }

        result = renderer.send(:format_operation, op)

        expect(result).to eq("+calculate(x: Integer): Boolean")
      end

      it "handles missing return type" do
        op = { name: "doSomething", visibility: "public", parameters: [] }

        result = renderer.send(:format_operation, op)

        expect(result).to eq("+doSomething()")
      end

      it "handles multiple parameters" do
        op = {
          name: "add",
          visibility: "public",
          parameters: [
            { name: "a", type: "Integer" },
            { name: "b", type: "Integer" }
          ],
          return_type: "Integer"
        }

        result = renderer.send(:format_operation, op)

        expect(result).to eq("+add(a: Integer, b: Integer): Integer")
      end

      it "handles plain string operation" do
        result = renderer.send(:format_operation, "method()")

        expect(result).to eq("method()")
      end
    end

    describe "#format_parameters" do
      it "formats array of parameter hashes" do
        params = [
          { name: "x", type: "Integer" },
          { name: "y", type: "String" }
        ]

        result = renderer.send(:format_parameters, params)

        expect(result).to eq("x: Integer, y: String")
      end

      it "handles plain string parameters" do
        params = ["param1", "param2"]

        result = renderer.send(:format_parameters, params)

        expect(result).to eq("param1, param2")
      end

      it "handles empty parameters" do
        result = renderer.send(:format_parameters, [])

        expect(result).to eq("")
      end

      it "handles mixed hash and string parameters" do
        params = [{ name: "x", type: "Integer" }, "other"]

        result = renderer.send(:format_parameters, params)

        expect(result).to eq("x: Integer, other")
      end
    end

    describe "#visibility_symbol" do
      it "returns + for public" do
        symbol = renderer.send(:visibility_symbol, "public")

        expect(symbol).to eq("+")
      end

      it "returns - for private" do
        symbol = renderer.send(:visibility_symbol, "private")

        expect(symbol).to eq("-")
      end

      it "returns # for protected" do
        symbol = renderer.send(:visibility_symbol, "protected")

        expect(symbol).to eq("#")
      end

      it "returns ~ for package" do
        symbol = renderer.send(:visibility_symbol, "package")

        expect(symbol).to eq("~")
      end

      it "returns empty string for unknown visibility" do
        symbol = renderer.send(:visibility_symbol, "unknown")

        expect(symbol).to eq("")
      end

      it "returns empty string for nil visibility" do
        symbol = renderer.send(:visibility_symbol, nil)

        expect(symbol).to eq("")
      end

      it "handles symbol input" do
        symbol = renderer.send(:visibility_symbol, :public)

        expect(symbol).to eq("+")
      end
    end

    describe "#render_text_element" do
      let(:style) do
        {
          font_family: "Arial",
          font_size: 12,
          font_weight: 700,
          font_style: "italic"
        }
      end

      it "renders SVG text element" do
        text = renderer.send(:render_text_element, "Test", 100, 50, style, "test-class")

        expect(text).to include("<text")
        expect(text).to include("</text>")
      end

      it "positions text at specified coordinates" do
        text = renderer.send(:render_text_element, "Test", 100, 50, style, "test-class")

        expect(text).to include(/x\=\"100/)
        expect(text).to include(/y\=\"50/)
      end

      it "includes CSS class" do
        text = renderer.send(:render_text_element, "Test", 100, 50, style, "my-class")

        expect(text).to include('class="my-class"')
      end

      it "applies font styles" do
        text = renderer.send(:render_text_element, "Test", 100, 50, style, "test-class")

        expect(text).to include("font-family:Arial")
        expect(text).to include("font-weight:700")
        expect(text).to include("font-style:italic")
        expect(text).to include("font-size:12")
      end

      it "escapes text content" do
        text = renderer.send(:render_text_element, "<tag>", 100, 50, style, "test-class")

        expect(text).to include("&lt;tag&gt;")
      end

      it "returns empty string for nil text" do
        text = renderer.send(:render_text_element, nil, 100, 50, style, "test-class")

        expect(text).to eq("")
      end

      it "accepts custom options" do
        text = renderer.send(:render_text_element, "Test", 100, 50, style, "test-class",
          font_size: "14pt",
          text_anchor: "end",
          fill: "#FF0000"
        )

        expect(text).to include("font-size:14pt")
        expect(text).to include('text-anchor="end"')
        expect(text).to include("fill:#FF0000")
      end
    end
  end
end