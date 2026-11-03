# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/spa/svg/style_configuration"

RSpec.describe Lutaml::Xsd::Spa::Svg::StyleConfiguration do
  describe ".load" do
    it "loads configuration from default paths" do
      config = described_class.load

      expect(config).to be_a(described_class)
      expect(config.colors).to be_a(Lutaml::Xsd::Spa::Svg::Config::ColorScheme)
      expect(config.dimensions).to be_a(Lutaml::Xsd::Spa::Svg::Config::Dimensions)
      expect(config.effects).to be_a(Lutaml::Xsd::Spa::Svg::Config::Effects)
      expect(config.connectors).to be_a(Lutaml::Xsd::Spa::Svg::Config::ConnectorStyles)
      expect(config.layout_config).to be_a(Lutaml::Xsd::Spa::Svg::Config::LayoutConfig)
    end

    it "provides access to element colors" do
      config = described_class.load

      expect(config.colors.element.base).to eq("#0066CC")
      expect(config.colors.element.gradient_start).to eq("#0077DD")
      expect(config.colors.element.gradient_end).to eq("#0055BB")
    end

    it "provides access to type colors" do
      config = described_class.load

      expect(config.colors.type.base).to eq("#006600")
      expect(config.colors.type.gradient_start).to eq("#007700")
      expect(config.colors.type.gradient_end).to eq("#005500")
    end

    it "provides access to attribute colors" do
      config = described_class.load

      expect(config.colors.attribute.base).to eq("#993333")
      expect(config.colors.attribute.gradient_start).to eq("#AA4444")
      expect(config.colors.attribute.gradient_end).to eq("#882222")
    end

    it "provides access to group colors" do
      config = described_class.load

      expect(config.colors.group.base).to eq("#FFCC00")
      expect(config.colors.group.gradient_start).to eq("#FFDD11")
      expect(config.colors.group.gradient_end).to eq("#EEBB00")
    end

    it "provides access to UI colors" do
      config = described_class.load

      expect(config.colors.ui.text).to eq("#000000")
      expect(config.colors.ui.border).to eq("#333333")
      expect(config.colors.ui.shadow).to eq("rgba(0,0,0,0.3)")
      expect(config.colors.ui.background).to eq("#FFFFFF")
    end

    it "provides access to indicator colors" do
      config = described_class.load

      expect(config.colors.indicators.required).to eq("#FF0000")
      expect(config.colors.indicators.optional).to eq("#888888")
      expect(config.colors.indicators.abstract).to eq("#9900CC")
    end

    it "provides access to dimensions" do
      config = described_class.load

      expect(config.dimensions.box_width).to eq(120)
      expect(config.dimensions.box_height).to eq(30)
      expect(config.dimensions.box_corner_radius).to eq(5)
      expect(config.dimensions.spacing_horizontal).to eq(20)
      expect(config.dimensions.spacing_vertical).to eq(15)
      expect(config.dimensions.spacing_indent).to eq(40)
      expect(config.dimensions.text_offset_y).to eq(20)
      expect(config.dimensions.text_font_size).to eq(14)
      expect(config.dimensions.text_small_font_size).to eq(10)
      expect(config.dimensions.text_icon_size).to eq(16)
    end

    it "provides access to effects configuration" do
      config = described_class.load

      expect(config.effects.shadow_enabled?).to be true
      expect(config.effects.shadow_blur).to eq(2)
      expect(config.effects.shadow_offset_x).to eq(2)
      expect(config.effects.shadow_offset_y).to eq(2)
      expect(config.effects.shadow_opacity).to eq(0.3)
      expect(config.effects.gradient_enabled?).to be true
      expect(config.effects.gradient_direction).to eq("vertical")
    end

    it "provides access to connector styles" do
      config = described_class.load

      inheritance = config.connectors.inheritance
      expect(inheritance.type).to eq("hollow_triangle")
      expect(inheritance.stroke_width).to eq(2)
      expect(inheritance.arrow_size).to eq(8)

      containment = config.connectors.containment
      expect(containment.type).to eq("solid_triangle")
      expect(containment.stroke_width).to eq(2)
      expect(containment.arrow_size).to eq(6)

      reference = config.connectors.reference
      expect(reference.type).to eq("dashed_hollow_triangle")
      expect(reference.stroke_width).to eq(2)
      expect(reference.arrow_size).to eq(6)
      expect(reference.dash_pattern).to eq("5,5")
      expect(reference.dashed?).to be true
    end

    it "provides access to layout configuration" do
      config = described_class.load

      expect(config.layout_config.default).to eq("tree")
      expect(config.layout_config.tree.direction).to eq("top_down")
      expect(config.layout_config.tree.level_spacing).to eq(60)
      expect(config.layout_config.vertical.item_spacing).to eq(15)
    end

    it "provides access to component rules" do
      config = described_class.load

      element_rule = config.component_rule("element")
      expect(element_rule.icon).to eq("E")
      expect(element_rule.show_cardinality?).to be true
      expect(element_rule.show_namespace?).to be true
      expect(element_rule.clickable?).to be true
      expect(element_rule.filter).to eq("dropShadow")

      type_rule = config.component_rule("type")
      expect(type_rule.icon).to eq("T")
      expect(type_rule.show_base_type?).to be true
      expect(type_rule.show_derivation?).to be true
      expect(type_rule.clickable?).to be true

      attribute_rule = config.component_rule("attribute")
      expect(attribute_rule.icon).to eq("@")
      expect(attribute_rule.show_type?).to be true
      expect(attribute_rule.show_default?).to be true
      expect(attribute_rule.clickable?).to be false
      expect(attribute_rule.filter).to be_nil

      group_rule = config.component_rule("group")
      expect(group_rule.icon).to be_nil
      expect(group_rule.show_type?).to be true
      expect(group_rule.clickable?).to be false
    end

    it "provides access to indicator rules" do
      config = described_class.load

      abstract_rule = config.indicator_rule("abstract")
      expect(abstract_rule.text).to eq("«abstract»")
      expect(abstract_rule.position).to eq("top_right")
      expect(abstract_rule.style).to eq("italic")
      expect(abstract_rule.offset_x).to eq(-5)
      expect(abstract_rule.offset_y).to eq(12)

      optional_rule = config.indicator_rule("optional")
      expect(optional_rule.text).to eq("?")
      expect(optional_rule.position).to eq("top_right")
      expect(optional_rule.style).to eq("normal")

      required_rule = config.indicator_rule("required")
      expect(required_rule.text).to eq("*")
      expect(required_rule.position).to eq("top_right")
      expect(required_rule.style).to eq("bold")
    end
  end

  describe "#layout_type" do
    it "returns the default layout type" do
      config = described_class.load

      expect(config.layout_type).to eq("tree")
    end
  end

  describe "#initialize" do
    it "handles empty configuration hashes" do
      config = described_class.new({}, {})

      expect(config.colors).to be_a(Lutaml::Xsd::Spa::Svg::Config::ColorScheme)
      expect(config.dimensions).to be_a(Lutaml::Xsd::Spa::Svg::Config::Dimensions)
      expect(config.effects).to be_a(Lutaml::Xsd::Spa::Svg::Config::Effects)
      expect(config.connectors).to be_a(Lutaml::Xsd::Spa::Svg::Config::ConnectorStyles)
      expect(config.layout_config).to be_a(Lutaml::Xsd::Spa::Svg::Config::LayoutConfig)
    end

    it "provides sensible defaults for missing values" do
      config = described_class.new({}, {})

      # Dimensions should have defaults
      expect(config.dimensions.box_width).to eq(120)
      expect(config.dimensions.box_height).to eq(30)

      # Effects should have defaults
      expect(config.effects.shadow_enabled?).to be true
      expect(config.effects.gradient_enabled?).to be true

      # Layout should have defaults
      expect(config.layout_type).to eq("tree")
    end
  end
end
