# frozen_string_literal: true

require_relative "point"

module Lutaml
  module Xsd
    module Spa
      module Svg
        module Geometry
          # Immutable value object representing a rectangular box
          class Box
            attr_reader :x, :y, :width, :height

            def initialize(x, y, width, height)
              @x = x.to_f
              @y = y.to_f
              @width = width.to_f
              @height = height.to_f
            end

            def top_left
              Point.new(x, y)
            end

            def top_right
              Point.new(x + width, y)
            end

            def bottom_left
              Point.new(x, y + height)
            end

            def bottom_right
              Point.new(x + width, y + height)
            end

            def center
              Point.new(x + (width / 2.0), y + (height / 2.0))
            end

            def top_center
              Point.new(x + (width / 2.0), y)
            end

            def bottom_center
              Point.new(x + (width / 2.0), y + height)
            end

            def left_center
              Point.new(x, y + (height / 2.0))
            end

            def right_center
              Point.new(x + width, y + (height / 2.0))
            end

            def contains?(point)
              point.x.between?(x, x + width) &&
                point.y >= y && point.y <= (y + height)
            end
          end
        end
      end
    end
  end
end
