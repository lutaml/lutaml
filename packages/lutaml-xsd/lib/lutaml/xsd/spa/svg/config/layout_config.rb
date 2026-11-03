# frozen_string_literal: true

module Lutaml
  module Xsd
    module Spa
      module Svg
        module Config
          # Value object for layout configuration
          class LayoutConfig
            attr_reader :default, :tree, :vertical

            def initialize(layout_hash)
              @layout = layout_hash
              @default = @layout["default"] || "tree"
              @tree = TreeLayoutConfig.new(@layout["tree"] || {})
              @vertical = VerticalLayoutConfig.new(@layout["vertical"] || {})
            end
          end

          # Tree layout configuration value object
          class TreeLayoutConfig
            attr_reader :direction, :level_spacing

            def initialize(tree_hash)
              @direction = tree_hash["direction"] || "top_down"
              @level_spacing = tree_hash["level_spacing"] || 60
            end
          end

          # Vertical layout configuration value object
          class VerticalLayoutConfig
            attr_reader :item_spacing

            def initialize(vertical_hash)
              @item_spacing = vertical_hash["item_spacing"] || 15
            end
          end
        end
      end
    end
  end
end
