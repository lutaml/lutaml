# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/spa/svg/renderers/attribute_renderer"
require "lutaml/xsd/spa/svg/style_configuration"
require "lutaml/xsd/spa/svg/geometry/box"

RSpec.describe Lutaml::Xsd::Spa::Svg::Renderers::AttributeRenderer do
  let(:config) { Lutaml::Xsd::Spa::Svg::StyleConfiguration.load }
  let(:schema_name) { "test_schema" }
  let(:renderer) { described_class.new(config, schema_name) }
  let(:box) { Lutaml::Xsd::Spa::Svg::Geometry::Box.new(10, 20, 120, 30) }

  describe "#render" do
    it "renders a basic attribute" do
      attr_data = { "name" => "id" }
      result = renderer.render(attr_data, box)

      expect(result).to include("<g")
      expect(result).to include("attribute-box")
      expect(result).to include("@id")
    end

    it "renders attribute with type" do
      attr_data = { "name" => "id", "type" => "xs:string" }
      result = renderer.render(attr_data, box)

      expect(result).to include("@id")
      expect(result).to include("xs:string")
    end

    it "renders with gradient when enabled" do
      attr_data = { "name" => "id" }
      result = renderer.render(attr_data, box)

      expect(result).to include("url(#attributeGradient)")
    end

    it "renders required indicator for required attributes" do
      attr_data = { "name" => "id", "use" => "required" }
      result = renderer.render(attr_data, box)

      expect(result).to include("*")
    end

    it "does not render indicator for optional attributes" do
      attr_data = { "name" => "id", "use" => "optional" }
      result = renderer.render(attr_data, box)

      expect(result).not_to include("*")
    end

    it "includes @ prefix for attribute name" do
      attr_data = { "name" => "version" }
      result = renderer.render(attr_data, box)

      expect(result).to include("@version")
    end
  end
end
