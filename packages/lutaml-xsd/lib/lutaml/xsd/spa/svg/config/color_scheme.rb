# frozen_string_literal: true

module Lutaml
  module Xsd
    module Spa
      module Svg
        module Config
          # Value object for color configuration
          class ColorScheme
            def initialize(colors_hash)
              @colors = colors_hash
            end

            def element
              ComponentColors.new(@colors["element"] || {})
            end

            def type
              ComponentColors.new(@colors["type"] || {})
            end

            def attribute
              ComponentColors.new(@colors["attribute"] || {})
            end

            def group
              ComponentColors.new(@colors["group"] || {})
            end

            def ui
              UIColors.new(@colors["ui"] || {})
            end

            def indicators
              IndicatorColors.new(@colors["indicators"] || {})
            end
          end

          # Component color value object
          class ComponentColors
            attr_reader :base, :gradient_start, :gradient_end

            def initialize(colors_hash)
              @base = colors_hash["base"]
              @gradient_start = colors_hash["gradient_start"]
              @gradient_end = colors_hash["gradient_end"]
            end
          end

          # UI color value object
          class UIColors
            attr_reader :text, :border, :shadow, :background

            def initialize(colors_hash)
              @text = colors_hash["text"]
              @border = colors_hash["border"]
              @shadow = colors_hash["shadow"]
              @background = colors_hash["background"]
            end
          end

          # Indicator color value object
          class IndicatorColors
            attr_reader :required, :optional, :abstract

            def initialize(colors_hash)
              @required = colors_hash["required"]
              @optional = colors_hash["optional"]
              @abstract = colors_hash["abstract"]
            end

            def color_for(type)
              case type.to_sym
              when :required then @required
              when :optional then @optional
              when :abstract then @abstract
              end
            end
          end
        end
      end
    end
  end
end
