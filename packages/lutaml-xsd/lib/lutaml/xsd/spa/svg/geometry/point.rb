# frozen_string_literal: true

module Lutaml
  module Xsd
    module Spa
      module Svg
        module Geometry
          # Immutable value object representing a 2D point
          class Point
            attr_reader :x, :y

            def initialize(x, y)
              @x = x.to_f
              @y = y.to_f
            end

            def ==(other)
              other.is_a?(Point) && x == other.x && y == other.y
            end

            def to_s
              "(#{x}, #{y})"
            end

            def distance_to(other)
              Math.sqrt(((x - other.x)**2) + ((y - other.y)**2))
            end

            def midpoint_to(other)
              Point.new((x + other.x) / 2.0, (y + other.y) / 2.0)
            end

            def offset(dx, dy)
              Point.new(x + dx, y + dy)
            end
          end
        end
      end
    end
  end
end
