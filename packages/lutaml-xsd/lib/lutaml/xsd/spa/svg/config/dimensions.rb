# frozen_string_literal: true

module Lutaml
  module Xsd
    module Spa
      module Svg
        module Config
          # Value object for dimension configuration
          class Dimensions
            def initialize(dimensions_hash)
              @dimensions = dimensions_hash
              @box = BoxDimensions.new(@dimensions["box"] || {})
              @spacing = SpacingDimensions.new(@dimensions["spacing"] || {})
              @text = TextDimensions.new(@dimensions["text"] || {})
            end

            def box_width
              @box.width
            end

            def box_height
              @box.height
            end

            def box_corner_radius
              @box.corner_radius
            end

            def spacing_horizontal
              @spacing.horizontal
            end

            def spacing_vertical
              @spacing.vertical
            end

            def spacing_indent
              @spacing.indent
            end

            def text_offset_y
              @text.offset_y
            end

            def text_font_size
              @text.font_size
            end

            def text_small_font_size
              @text.small_font_size
            end

            def text_icon_size
              @text.icon_size
            end
          end

          # Box dimension value object
          class BoxDimensions
            attr_reader :width, :height, :corner_radius

            def initialize(box_hash)
              @width = box_hash["width"] || 120
              @height = box_hash["height"] || 30
              @corner_radius = box_hash["corner_radius"] || 5
            end
          end

          # Spacing dimension value object
          class SpacingDimensions
            attr_reader :horizontal, :vertical, :indent

            def initialize(spacing_hash)
              @horizontal = spacing_hash["horizontal"] || 20
              @vertical = spacing_hash["vertical"] || 15
              @indent = spacing_hash["indent"] || 40
            end
          end

          # Text dimension value object
          class TextDimensions
            attr_reader :offset_y, :font_size, :small_font_size, :icon_size

            def initialize(text_hash)
              @offset_y = text_hash["offset_y"] || 20
              @font_size = text_hash["font_size"] || 14
              @small_font_size = text_hash["small_font_size"] || 10
              @icon_size = text_hash["icon_size"] || 16
            end
          end
        end
      end
    end
  end
end
