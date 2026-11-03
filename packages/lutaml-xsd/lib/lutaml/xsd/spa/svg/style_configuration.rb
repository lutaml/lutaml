# frozen_string_literal: true

require "yaml"
require_relative "config/color_scheme"
require_relative "config/dimensions"
require_relative "config/effects"
require_relative "config/connector_styles"
require_relative "config/layout_config"
require_relative "config/component_rules"
require_relative "config/indicator_rules"

module Lutaml
  module Xsd
    module Spa
      module Svg
        # Loads and provides access to SVG styling configuration
        class StyleConfiguration
          attr_reader :colors, :dimensions, :effects, :connectors,
                      :layout_config

          def self.load(styles_path = nil, rules_path = nil)
            styles_path ||= default_styles_path
            rules_path ||= default_rules_path

            styles = YAML.load_file(styles_path)
            rules = File.exist?(rules_path) ? YAML.load_file(rules_path) : {}

            new(styles, rules)
          end

          def initialize(styles_hash, rules_hash = {})
            @colors = Config::ColorScheme.new(styles_hash["colors"] || {})
            @dimensions = Config::Dimensions.new(styles_hash["dimensions"] || {})
            @effects = Config::Effects.new(styles_hash["effects"] || {})
            @connectors = Config::ConnectorStyles.new(styles_hash["connectors"] || {})
            @layout_config = Config::LayoutConfig.new(styles_hash["layout"] || {})
            @component_rules = Config::ComponentRules.new(rules_hash["components"] || {})
            @indicator_rules = Config::IndicatorRules.new(rules_hash["indicators"] || {})
          end

          def layout_type
            @layout_config.default
          end

          def component_rule(component_type)
            @component_rules.rule_for(component_type)
          end

          def indicator_rule(indicator_type)
            @indicator_rules.rule_for(indicator_type)
          end

          def self.default_styles_path
            File.join(__dir__, "../../../../../config/spa/svg_styles.yml")
          end

          def self.default_rules_path
            File.join(__dir__,
                      "../../../../../config/spa/svg_component_rules.yml")
          end
        end
      end
    end
  end
end
