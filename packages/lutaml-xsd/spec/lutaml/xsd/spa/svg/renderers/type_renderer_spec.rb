# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/spa/svg/renderers/type_renderer"
require "lutaml/xsd/spa/svg/style_configuration"
require "lutaml/xsd/spa/svg/geometry/box"

RSpec.describe Lutaml::Xsd::Spa::Svg::Renderers::TypeRenderer do
  let(:config) { Lutaml::Xsd::Spa::Svg::StyleConfiguration.load }
  let(:schema_name) { "test_schema" }
  let(:renderer) { described_class.new(config, schema_name) }
  let(:box) { Lutaml::Xsd::Spa::Svg::Geometry::Box.new(10, 20, 120, 30) }

  describe "#render" do
    it "renders a basic type" do
      type_data = { "name" => "PersonType" }
      result = renderer.render(type_data, box)

      expect(result).to include("<g")
      expect(result).to include("type-box")
      expect(result).to include("PersonType")
    end

    it "renders a clickable type when configured" do
      type_data = { "name" => "PersonType" }
      result = renderer.render(type_data, box)

      expect(result).to include("<a")
      expect(result).to include("href")
      expect(result).to include("#/schemas/test_schema/types/person-type")
    end

    it "renders with gradient when enabled" do
      type_data = { "name" => "PersonType" }
      result = renderer.render(type_data, box)

      expect(result).to include("url(#typeGradient)")
    end

    it "renders abstract indicator for abstract types" do
      type_data = { "name" => "AbstractType", "abstract" => true }
      result = renderer.render(type_data, box)

      expect(result).to include("«abstract»")
    end

    it "does not render indicator for non-abstract types" do
      type_data = { "name" => "ConcreteType", "abstract" => false }
      result = renderer.render(type_data, box)

      expect(result).not_to include("«abstract»")
    end

    it "includes centered text" do
      type_data = { "name" => "PersonType" }
      result = renderer.render(type_data, box)

      expect(result).to include('text-anchor="middle"')
      expect(result).to include("PersonType")
    end
  end
end
