# frozen_string_literal: true

module Lutaml
  module Xsd
    module Spa
      module Svg
        module Config
          # Value object for indicator rendering rules
          class IndicatorRules
            def initialize(indicators_hash)
              @indicators = indicators_hash
            end

            def rule_for(indicator_type)
              IndicatorRule.new(@indicators[indicator_type.to_s] || {})
            end

            def abstract
              rule_for("abstract")
            end

            def optional
              rule_for("optional")
            end

            def required
              rule_for("required")
            end
          end

          # Individual indicator rule value object
          class IndicatorRule
            attr_reader :text, :position, :style, :offset_x, :offset_y

            def initialize(rule_hash)
              @text = rule_hash["text"] || ""
              @position = rule_hash["position"] || "top_right"
              @style = rule_hash["style"] || "normal"
              @offset_x = rule_hash["offset_x"] || -5
              @offset_y = rule_hash["offset_y"] || 12
            end
          end
        end
      end
    end
  end
end
