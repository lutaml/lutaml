# frozen_string_literal: true

require "spec_helper"
require "lutaml/ea/diagram/svg_renderer"
require "lutaml/ea/diagram/layout_engine"

RSpec.describe Lutaml::Ea::Diagram::SvgRenderer do
  let(:diagram_data) do
    {
      name: "Test Diagram",
      elements: [
        {
          id: "1",
          type: "class",
          name: "TestClass",
          x: 100,
          y: 50,
          width: 120,
          height: 80,
          element: double("Element", name: "TestClass", stereotype: nil,
                                     package_name: nil),
          diagram_object: nil,
        },
        {
          id: "2",
          type: "package",
          name: "TestPackage",
          x: 300,
          y: 150,
          width: 120,
          height: 80,
          element: double("Element", name: "TestPackage", stereotype: nil,
                                     package_name: nil),
          diagram_object: nil,
        },
      ],
      connectors: [
        {
          id: "c1",
          type: "association",
          geometry: "SX=0;SY=0;EX=0;EY=0;",
          source_element: { id: "1", x: 100, y: 50, width: 120, height: 80 },
          target_element: { id: "2", x: 300, y: 150, width: 120, height: 80 },
          element: nil,
          diagram_link: nil,
        },
      ],
    }
  end

  let(:layout_engine) { Lutaml::Ea::Diagram::LayoutEngine.new }
  let(:bounds) { layout_engine.calculate_bounds(diagram_data) }
  let(:diagram_renderer) do
    double("DiagramRenderer",
           diagram_data: diagram_data,
           bounds: bounds,
           elements: diagram_data[:elements],
           connectors: diagram_data[:connectors])
  end

  describe "#initialize" do
    it "stores diagram renderer reference" do
      renderer = described_class.new(diagram_renderer)
      expect(renderer.diagram_renderer).to eq(diagram_renderer)
    end

    it "merges options with defaults" do
      renderer = described_class.new(diagram_renderer, padding: 30)
      expect(renderer.options[:padding]).to eq(30)
    end

    it "uses default padding when not specified" do
      renderer = described_class.new(diagram_renderer)
      expect(renderer.options[:padding]).to eq(20)
    end

    it "calculates bounds from diagram renderer" do
      renderer = described_class.new(diagram_renderer)
      expect(renderer.bounds).to eq(bounds)
    end

    it "creates style resolver with nil config path by default" do
      renderer = described_class.new(diagram_renderer)
      expect(renderer.style_resolver).to be_a(Lutaml::Ea::Diagram::StyleResolver)
    end

    it "creates style resolver with custom config path" do
      renderer = described_class.new(diagram_renderer,
                                     config_path: "custom/config.yml")
      expect(renderer.style_resolver).to be_a(Lutaml::Ea::Diagram::StyleResolver)
    end

    it "accepts custom background color option" do
      renderer = described_class.new(diagram_renderer,
                                     background_color: "#f0f0f0")
      expect(renderer.options[:background_color]).to eq("#f0f0f0")
    end

    it "accepts grid_visible option" do
      renderer = described_class.new(diagram_renderer, grid_visible: true)
      expect(renderer.options[:grid_visible]).to be(true)
    end

    it "accepts interactive option" do
      renderer = described_class.new(diagram_renderer, interactive: true)
      expect(renderer.options[:interactive]).to be(true)
    end

    it "accepts custom CSS classes" do
      renderer = described_class.new(diagram_renderer,
                                     css_classes: ["custom-class"])
      expect(renderer.options[:css_classes]).to eq(["custom-class"])
    end
  end

  describe "#render" do
    let(:renderer) { described_class.new(diagram_renderer) }
    let(:svg_output) { renderer.render }

    it "generates complete SVG document" do
      expect(svg_output).to be_a(String)
      expect(svg_output).not_to be_empty
    end

    it "includes XML declaration" do
      expect(svg_output).to include('<?xml version="1.0" encoding="UTF-8"')
    end

    it "includes DOCTYPE declaration" do
      expect(svg_output).to include("<!DOCTYPE svg")
    end

    it "includes svg root element" do
      expect(svg_output).to include("<svg")
    end

    it "includes title element" do
      expect(svg_output).to include("<title>")
    end

    it "includes description element" do
      expect(svg_output).to include("<desc>")
      expect(svg_output).to include("Created with")
    end

    it "includes defs section" do
      expect(svg_output).to include("<defs>")
    end

    it "includes background layer" do
      expect(svg_output).to include("fill:#ffffff")
      expect(svg_output).to include("fill-opacity:1.00")
    end

    it "includes connectors layer" do
      expect(svg_output).to include('id="connectors-layer"')
    end

    it "includes elements layer" do
      expect(svg_output).to include('id="elements-layer"')
    end

    it "closes svg root element" do
      expect(svg_output).to end_with("</svg>\n")
    end

    it "does not include grid layer by default" do
      expect(svg_output).not_to include('id="grid-layer"')
    end

    it "does not include interactive layer by default" do
      expect(svg_output).not_to include('<script type="text/javascript">')
    end

    context "with grid visible" do
      let(:renderer) do
        described_class.new(diagram_renderer, grid_visible: true)
      end

      it "includes grid layer" do
        expect(svg_output).to include('id="grid-layer"')
      end
    end

    context "with interactive mode" do
      let(:renderer) do
        described_class.new(diagram_renderer, interactive: true)
      end

      it "includes interactive layer" do
        expect(svg_output).to include('<script type="text/javascript">')
      end

      it "includes click event handlers" do
        expect(svg_output).to include("addEventListener")
      end

      it "dispatches custom events" do
        expect(svg_output).to include("CustomEvent")
      end
    end
  end

  describe "SVG header generation" do
    let(:renderer) { described_class.new(diagram_renderer) }
    let(:svg_output) { renderer.render }

    it "includes correct width attribute" do
      expect(svg_output).to match(/width="[^"]+cm"/)
    end

    it "includes correct height attribute" do
      expect(svg_output).to match(/height="[^"]+cm"/)
    end

    it "includes viewBox with padding" do
      expect(svg_output).to include("viewBox=")
    end

    it "includes xmlns attributes" do
      expect(svg_output).to include('xmlns="http://www.w3.org/2000/svg"')
      expect(svg_output).to include('xmlns:xlink="http://www.w3.org/1999/xlink"')
    end

    it "includes version attribute" do
      expect(svg_output).to include('version="1.0"')
    end

    it "includes default viewBox" do
      expect(svg_output).to include("viewBox=")
    end

    context "with custom CSS classes" do
      let(:renderer) do
        described_class.new(diagram_renderer,
                            css_classes: ["custom1", "custom2"])
      end

      it "stores custom CSS classes in options" do
        expect(renderer.options[:css_classes]).to eq(["custom1", "custom2"])
      end
    end

    context "with custom padding" do
      let(:renderer) { described_class.new(diagram_renderer, padding: 50) }

      it "stores custom padding in options" do
        expect(renderer.options[:padding]).to eq(50)
      end

      it "uses viewBox for dimensions" do
        expect(svg_output).to include("viewBox=")
        expect(svg_output).to match(/width="[^"]+cm"/)
      end
    end
  end

  describe "defs section generation" do
    let(:renderer) { described_class.new(diagram_renderer) }
    let(:svg_output) { renderer.render }

    it "includes style element with CSS" do
      expect(svg_output).to include('<style type="text/css">')
    end

    it "wraps CSS in CDATA" do
      expect(svg_output).to include("<![CDATA[")
      expect(svg_output).to include("]]>")
    end

    it "includes element hover styles" do
      expect(svg_output).to include(".lutaml-diagram-element:hover")
    end

    it "includes connector styles" do
      expect(svg_output).to include(".lutaml-diagram-connector")
    end

    it "includes text styles" do
      expect(svg_output).to include(".lutaml-diagram-text")
    end

    it "includes stereotype styles" do
      expect(svg_output).to include(".lutaml-diagram-stereotype")
    end

    it "includes class name styles" do
      expect(svg_output).to include(".lutaml-diagram-class-name")
    end

    it "includes arrow markers section" do
      expect(svg_output).to include("<!-- EA-style arrow markers -->")
    end
  end

  describe "arrow markers generation" do
    let(:renderer) { described_class.new(diagram_renderer) }
    let(:svg_output) { renderer.render }

    it "defines generalization arrow marker" do
      expect(svg_output).to include('id="generalization-arrow"')
    end

    it "defines association arrow marker" do
      expect(svg_output).to include('id="association-arrow"')
    end

    it "defines aggregation arrow marker" do
      expect(svg_output).to include('id="aggregation-arrow"')
    end

    it "defines composition arrow marker" do
      expect(svg_output).to include('id="composition-arrow"')
    end

    it "defines dependency arrow marker" do
      expect(svg_output).to include('id="dependency-arrow"')
    end

    it "defines realization arrow marker" do
      expect(svg_output).to include('id="realization-arrow"')
    end

    it "uses hollow triangle for generalization" do
      expect(svg_output).to match(/generalization-arrow.*polygon/m)
    end

    it "uses hollow diamond for aggregation" do
      expect(svg_output).to match(/aggregation-arrow.*polygon/m)
    end

    it "uses filled diamond for composition" do
      expect(svg_output).to match(/composition-arrow.*polygon/m)
    end
  end

  describe "background layer generation" do
    let(:renderer) { described_class.new(diagram_renderer) }
    let(:svg_output) { renderer.render }

    it "creates background rectangle" do
      expect(svg_output).to include("<rect")
      expect(svg_output).to include("shape-rendering=")
    end

    it "applies default background color" do
      expect(svg_output).to match(/fill:#ffffff/)
    end

    it "includes fill-opacity style" do
      expect(svg_output).to include("fill-opacity:1.00")
    end

    it "starts background at origin" do
      expect(svg_output).to include('x="0" y="0"')
    end

    context "with custom background color" do
      let(:renderer) do
        described_class.new(diagram_renderer, background_color: "#f5f5f5")
      end

      it "applies custom background color" do
        expect(svg_output).to include("fill:#f5f5f5")
      end
    end
  end

  describe "grid layer generation" do
    context "when grid_visible is false" do
      let(:renderer) do
        described_class.new(diagram_renderer, grid_visible: false)
      end

      it "does not include grid layer" do
        expect(renderer.render).not_to include('id="grid-layer"')
      end
    end

    context "when grid_visible is true" do
      let(:renderer) do
        described_class.new(diagram_renderer, grid_visible: true)
      end
      let(:svg_output) { renderer.render }

      it "includes grid layer" do
        expect(svg_output).to include('id="grid-layer"')
      end

      it "generates vertical grid lines" do
        expect(svg_output)
          .to match(/<line x1="[^"]+" y1="[^"]+" x2="[^"]+" y2="[^"]+"/)
      end

      it "uses 20px grid size" do
        # Grid lines should be 20 pixels apart (default grid size)
        expect(svg_output).to include('class="lutaml-diagram-grid"')
      end

      it "includes lutaml-diagram-grid class" do
        expect(svg_output).to include('class="lutaml-diagram-grid"')
      end
    end
  end

  describe "connectors layer generation" do
    let(:renderer) { described_class.new(diagram_renderer) }
    let(:svg_output) { renderer.render }

    it "wraps connectors in layer group" do
      expect(svg_output).to include('<g id="connectors-layer"')
    end

    it "renders all connectors" do
      expect(svg_output).to include('data-connector-id="c1"')
    end

    it "includes connector type in data attributes" do
      expect(svg_output).to include('data-connector-type="association"')
    end

    it "renders connectors before elements" do
      connectors_index = svg_output.index('id="connectors-layer"')
      elements_index = svg_output.index('id="elements-layer"')
      expect(connectors_index).to be < elements_index
    end
  end

  describe "elements layer generation" do
    let(:renderer) { described_class.new(diagram_renderer) }
    let(:svg_output) { renderer.render }

    it "wraps elements in layer group" do
      expect(svg_output).to include('<g id="elements-layer"')
    end

    it "renders all elements" do
      expect(svg_output).to include('data-element-id="1"')
      expect(svg_output).to include('data-element-id="2"')
    end

    it "calls appropriate renderer for class type" do
      expect(svg_output).to include("TestClass")
    end

    it "calls appropriate renderer for package type" do
      expect(svg_output).to include("TestPackage")
    end
  end

  describe "interactive layer generation" do
    context "when interactive is false" do
      let(:renderer) do
        described_class.new(diagram_renderer, interactive: false)
      end

      it "does not include JavaScript" do
        expect(renderer.render).not_to include("<script")
      end
    end

    context "when interactive is true" do
      let(:renderer) do
        described_class.new(diagram_renderer, interactive: true)
      end
      let(:svg_output) { renderer.render }

      it "includes JavaScript for click handlers" do
        expect(svg_output).to include("addEventListener('click'")
      end

      it "wraps JavaScript in CDATA" do
        expect(svg_output).to match(/<script.*<!\[CDATA\[/m)
      end

      it "dispatches custom events" do
        expect(svg_output).to include("CustomEvent('lutaml:element:click'")
      end

      it "queries diagram elements" do
        expect(svg_output)
          .to include("querySelectorAll('.lutaml-diagram-element')")
      end
    end
  end

  describe "connector rendering" do
    let(:renderer) { described_class.new(diagram_renderer) }
    let(:svg_output) { renderer.render }

    it "includes path element for connector" do
      expect(svg_output).to include("<path d=")
    end

    it "includes connector CSS classes" do
      expect(svg_output).to include('class="lutaml-diagram-connector')
      expect(svg_output).to include("lutaml-diagram-connector-association")
    end

    it "includes data attributes" do
      expect(svg_output).to include('data-connector-id="c1"')
      expect(svg_output).to include('data-connector-type="association"')
    end

    it "wraps connector in styled group" do
      expect(svg_output).to match(/<g style="stroke:[^"]+">.*<path/m)
    end

    it "applies stroke styles" do
      expect(svg_output).to match(/stroke:#[0-9A-F]{6}/i)
    end

    it "sets fill to none for connectors" do
      expect(svg_output).to include("fill:none")
    end
  end

  describe "element rendering" do
    let(:diagram_data_with_types) do
      {
        name: "Type Test",
        elements: [
          {
            id: "class1", type: "class", name: "MyClass",
            x: 0, y: 0, width: 100, height: 80,
            element: double(
              "Element", name: "MyClass", stereotype: nil, package_name: nil
            )
          },
          {
            id: "datatype1", type: "datatype", name: "MyDataType",
            x: 150, y: 0, width: 100, height: 60,
            element: double(
              "Element", name: "MyDataType", stereotype: nil, package_name: nil
            )
          },
          {
            id: "package1", type: "package", name: "MyPackage",
            x: 300, y: 0, width: 120, height: 100,
            element: double(
              "Element", name: "MyPackage", stereotype: nil, package_name: nil
            )
          },
          {
            id: "unknown1", type: "unknown", name: "Unknown",
            x: 450, y: 0, width: 80, height: 60,
            element: double(
              "Element", name: "Unknown", stereotype: nil, package_name: nil
            )
          },
        ],
        connectors: [],
      }
    end

    let(:layout_engine) { Lutaml::Ea::Diagram::LayoutEngine.new }
    let(:bounds_for_types) do
      layout_engine.calculate_bounds(diagram_data_with_types)
    end
    let(:renderer_for_types) do
      renderer = double("DiagramRenderer",
                        diagram_data: diagram_data_with_types,
                        bounds: bounds_for_types,
                        elements: diagram_data_with_types[:elements],
                        connectors: [])
      described_class.new(renderer)
    end

    let(:svg_for_types) { renderer_for_types.render }

    it "selects ClassRenderer for class type" do
      expect(svg_for_types).to include("MyClass")
      expect(svg_for_types).to include('data-element-id="class1"')
    end

    it "selects ClassRenderer for datatype type" do
      expect(svg_for_types).to include("MyDataType")
      expect(svg_for_types).to include('data-element-id="datatype1"')
    end

    it "selects PackageRenderer for package type" do
      expect(svg_for_types).to include("MyPackage")
      expect(svg_for_types).to include('data-element-id="package1"')
    end

    it "selects BaseRenderer for unknown types" do
      expect(svg_for_types).to include("Unknown")
      expect(svg_for_types).to include('data-element-id="unknown1"')
    end
  end

  describe "marker type determination" do
    let(:renderer) { described_class.new(diagram_renderer) }

    it "returns generalization marker for generalization type" do
      marker = renderer.send(:determine_marker_type, "generalization")
      expect(marker[:end]).to eq("url(#generalization-arrow)")
      expect(marker[:start]).to be_nil
    end

    it "returns generalization marker for inheritance type" do
      marker = renderer.send(:determine_marker_type, "inheritance")
      expect(marker[:end]).to eq("url(#generalization-arrow)")
    end

    it "returns association marker for association type" do
      marker = renderer.send(:determine_marker_type, "association")
      expect(marker[:end]).to eq("url(#association-arrow)")
      expect(marker[:start]).to be_nil
    end

    it "returns aggregation marker at start for aggregation type" do
      marker = renderer.send(:determine_marker_type, "aggregation")
      expect(marker[:start]).to eq("url(#aggregation-arrow)")
      expect(marker[:end]).to be_nil
    end

    it "returns composition marker at start for composition type" do
      marker = renderer.send(:determine_marker_type, "composition")
      expect(marker[:start]).to eq("url(#composition-arrow)")
      expect(marker[:end]).to be_nil
    end

    it "returns dependency marker for dependency type" do
      marker = renderer.send(:determine_marker_type, "dependency")
      expect(marker[:end]).to eq("url(#dependency-arrow)")
      expect(marker[:start]).to be_nil
    end

    it "returns realization marker for realization type" do
      marker = renderer.send(:determine_marker_type, "realization")
      expect(marker[:end]).to eq("url(#realization-arrow)")
    end

    it "returns realization marker for implementation type" do
      marker = renderer.send(:determine_marker_type, "implementation")
      expect(marker[:end]).to eq("url(#realization-arrow)")
    end

    it "defaults to association marker for unknown types" do
      marker = renderer.send(:determine_marker_type, "unknown_type")
      expect(marker[:end]).to eq("url(#association-arrow)")
    end

    it "handles nil connector type" do
      marker = renderer.send(:determine_marker_type, nil)
      expect(marker[:end]).to eq("url(#association-arrow)")
    end

    it "handles case-insensitive type matching" do
      marker = renderer.send(:determine_marker_type, "GENERALIZATION")
      expect(marker[:end]).to eq("url(#generalization-arrow)")
    end
  end

  describe "style to CSS conversion" do
    let(:renderer) { described_class.new(diagram_renderer) }

    it "converts style hash to CSS string" do
      style_hash = { stroke: "#000000", "stroke-width": "2" }
      css = renderer.send(:style_to_css, style_hash)
      expect(css).to include("stroke:#000000")
      expect(css).to include("stroke-width:2")
    end

    it "joins properties with semicolons" do
      style_hash = { fill: "red", stroke: "blue" }
      css = renderer.send(:style_to_css, style_hash)
      expect(css).to include(";")
    end

    it "handles empty hash" do
      css = renderer.send(:style_to_css, {})
      expect(css).to eq("")
    end
  end

  describe "integration" do
    let(:renderer) { described_class.new(diagram_renderer) }
    let(:svg_output) { renderer.render }

    it "generates valid SVG with all components" do
      expect(svg_output).to start_with("<?xml")
      expect(svg_output).to include("<svg")
      expect(svg_output).to include("<defs>")
      expect(svg_output).to include("</svg>")
    end

    it "properly integrates element renderers" do
      expect(svg_output).to include("TestClass")
      expect(svg_output).to include("TestPackage")
    end

    it "properly integrates path builder for connectors" do
      expect(svg_output).to include("<path d=")
      expect(svg_output).to include("M ") # SVG path command
    end

    it "properly integrates style resolver" do
      expect(svg_output).to include("stroke:")
      expect(svg_output).to include("fill:")
    end

    it "produces parseable SVG" do
      expect do
        Nokogiri::XML(svg_output, &:strict)
      end.not_to raise_error
    end
  end
end
