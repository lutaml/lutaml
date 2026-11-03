# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/spa/svg/renderers/group_renderer"
require "lutaml/xsd/spa/svg/style_configuration"
require "lutaml/xsd/spa/svg/geometry/box"

RSpec.describe Lutaml::Xsd::Spa::Svg::Renderers::GroupRenderer do
  let(:config) { Lutaml::Xsd::Spa::Svg::StyleConfiguration.load }
  let(:schema_name) { "test_schema" }
  let(:renderer) { described_class.new(config, schema_name) }
  let(:box) { Lutaml::Xsd::Spa::Svg::Geometry::Box.new(10, 20, 120, 30) }

  describe "#render" do
    it "renders a sequence group" do
      group_data = { "type" => "sequence" }
      result = renderer.render(group_data, box)

      expect(result).to include("<g")
      expect(result).to include("group-box")
      expect(result).to include("sequence")
    end

    it "renders a choice group" do
      group_data = { "type" => "choice" }
      result = renderer.render(group_data, box)

      expect(result).to include("choice")
    end

    it "renders an all group" do
      group_data = { "type" => "all" }
      result = renderer.render(group_data, box)

      expect(result).to include("all")
    end

    it "renders with gradient when enabled" do
      group_data = { "type" => "sequence" }
      result = renderer.render(group_data, box)

      expect(result).to include("url(#groupGradient)")
    end

    it "uses kind attribute if type is missing" do
      group_data = { "kind" => "sequence" }
      result = renderer.render(group_data, box)

      expect(result).to include("sequence")
    end

    it "includes centered text" do
      group_data = { "type" => "sequence" }
      result = renderer.render(group_data, box)

      expect(result).to include('text-anchor="middle"')
      expect(result).to include('font-weight="bold"')
    end
  end
end
