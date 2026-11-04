# frozen_string_literal: true

require "spec_helper"
require "ostruct"
require "lutaml/xsd/spa/svg/document_builder"
require "lutaml/xsd/spa/svg/style_configuration"

RSpec.describe Lutaml::Xsd::Spa::Svg::DocumentBuilder do
  let(:config) { Lutaml::Xsd::Spa::Svg::StyleConfiguration.load }
  let(:builder) { described_class.new(config) }

  describe "#build" do
    let(:components) do
      [
        '<rect x="10" y="20" width="100" height="50" fill="#0066CC"/>',
        '<text x="50" y="45">Element</text>',
      ]
    end
    let(:dimensions) { OpenStruct.new(width: 800, height: 600) }

    it "returns a complete SVG document" do
      result = builder.build(components, dimensions)

      expect(result).to start_with("<svg")
      expect(result).to include("</svg>")
    end

    it "includes SVG namespace declarations" do
      result = builder.build(components, dimensions)

      expect(result).to include('xmlns="http://www.w3.org/2000/svg"')
      expect(result).to include('xmlns:xlink="http://www.w3.org/1999/xlink"')
    end

    it "sets width and height from dimensions" do
      result = builder.build(components, dimensions)

      expect(result).to include('width="800"')
      expect(result).to include('height="600"')
    end

    it "sets viewBox from dimensions" do
      result = builder.build(components, dimensions)

      expect(result).to include('viewBox="0 0 800 600"')
    end

    it "includes defs section" do
      result = builder.build(components, dimensions)

      expect(result).to include("<defs>")
      expect(result).to include("</defs>")
    end

    it "includes styles section" do
      result = builder.build(components, dimensions)

      expect(result).to include("<style>")
      expect(result).to include("</style>")
      expect(result).to include("CDATA")
    end

    it "includes hover styles for components" do
      result = builder.build(components, dimensions)

      expect(result).to include(".element-box:hover")
      expect(result).to include(".type-box:hover")
      expect(result).to include(".attribute-box:hover")
      expect(result).to include(".group-box:hover")
    end

    it "wraps components in diagram-content group" do
      result = builder.build(components, dimensions)

      expect(result).to include('<g id="diagram-content">')
      expect(result).to include("</g>")
    end

    it "includes all provided components" do
      result = builder.build(components, dimensions)

      components.each do |component|
        expect(result).to include(component)
      end
    end

    it "handles empty components array" do
      result = builder.build([], dimensions)

      expect(result).to include('<g id="diagram-content">')
      expect(result).to include("</g>")
    end
  end
end
