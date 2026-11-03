# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/spa/svg/defs_builder"
require "lutaml/xsd/spa/svg/style_configuration"

RSpec.describe Lutaml::Xsd::Spa::Svg::DefsBuilder do
  let(:config) { Lutaml::Xsd::Spa::Svg::StyleConfiguration.load }
  let(:builder) { described_class.new(config) }

  describe "#build" do
    it "returns SVG defs element" do
      result = builder.build

      expect(result).to start_with("<defs>")
      expect(result).to end_with("</defs>")
    end

    it "includes gradients when enabled" do
      result = builder.build

      expect(result).to include("<linearGradient")
      expect(result).to include('id="elementGradient"')
      expect(result).to include('id="typeGradient"')
      expect(result).to include('id="attributeGradient"')
      expect(result).to include('id="groupGradient"')
    end

    it "includes gradient colors from configuration" do
      result = builder.build

      expect(result).to include(config.colors.element.gradient_start)
      expect(result).to include(config.colors.element.gradient_end)
      expect(result).to include(config.colors.type.gradient_start)
      expect(result).to include(config.colors.type.gradient_end)
    end

    it "includes filters when shadow is enabled" do
      result = builder.build

      expect(result).to include("<filter")
      expect(result).to include('id="dropShadow"')
      expect(result).to include("feGaussianBlur")
      expect(result).to include("feOffset")
    end

    it "includes filter parameters from configuration" do
      result = builder.build

      expect(result).to include("stdDeviation=\"#{config.effects.shadow_blur}\"")
      expect(result).to include("dx=\"#{config.effects.shadow_offset_x}\"")
      expect(result).to include("dy=\"#{config.effects.shadow_offset_y}\"")
    end

    it "includes component icons" do
      result = builder.build

      expect(result).to include('id="elementIcon"')
      expect(result).to include('id="typeIcon"')
      expect(result).to include('id="attributeIcon"')
    end

    it "includes icon colors from configuration" do
      result = builder.build

      expect(result).to include(config.colors.element.base)
      expect(result).to include(config.colors.type.base)
      expect(result).to include(config.colors.attribute.base)
    end

    it "uses icon size from dimensions configuration" do
      result = builder.build
      icon_size = config.dimensions.text_icon_size

      expect(result).to include("width=\"#{icon_size}\"")
      expect(result).to include("height=\"#{icon_size}\"")
    end
  end
end
