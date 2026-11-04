# frozen_string_literal: true

require_relative "utils/svg_builder"

module Lutaml
  module Xsd
    module Spa
      module Svg
        # Abstract base class for connector renderers
        # Subclasses must implement #render method
        class ConnectorRenderer
          attr_reader :config, :style

          def initialize(config, connector_type)
            @config = config
            @style = config.connectors.for_type(connector_type)
          end

          # Renders a connector from one point to another
          # @param from_point [Geometry::Point] Starting point
          # @param to_point [Geometry::Point] Ending point
          # @return [String] SVG markup
          def render(from_point, to_point)
            raise NotImplementedError, "#{self.class} must implement #render"
          end

          protected

          # Creates a basic line
          def create_line(from_point, to_point, options = {})
            Utils::SvgBuilder.line(
              from_point.x, from_point.y,
              to_point.x, to_point.y,
              {
                stroke: options[:stroke] || config.colors.ui.border,
                "stroke-width" => options[:stroke_width] || style.stroke_width,
                "stroke-dasharray" => options[:dash_pattern],
              }.compact
            )
          end

          # Creates an arrow pointing down at the given point
          def create_arrow_down(point, options = {})
            size = options[:size] || style.arrow_size
            points = [
              point,
              point.offset(-size, -size * 1.25),
              point.offset(size, -size * 1.25),
            ]

            Utils::SvgBuilder.polygon(
              points,
              {
                fill: options[:fill] || config.colors.ui.border,
                stroke: options[:stroke],
                "stroke-width" => options[:stroke_width],
              }.compact,
            )
          end

          # Creates an arrow pointing up at the given point
          def create_arrow_up(point, options = {})
            size = options[:size] || style.arrow_size
            points = [
              point,
              point.offset(-size, size * 1.25),
              point.offset(size, size * 1.25),
            ]

            Utils::SvgBuilder.polygon(
              points,
              {
                fill: options[:fill] || config.colors.ui.border,
                stroke: options[:stroke],
                "stroke-width" => options[:stroke_width],
              }.compact,
            )
          end

          # Calculates the direction from one point to another
          def direction(from_point, to_point)
            dx = to_point.x - from_point.x
            dy = to_point.y - from_point.y

            if dy.abs > dx.abs
              dy.positive? ? :down : :up
            else
              dx.positive? ? :right : :left
            end
          end
        end
      end
    end
  end
end
