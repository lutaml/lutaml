# frozen_string_literal: true

require_relative "../connector_renderer"

module Lutaml
  module Xsd
    module Spa
      module Svg
        module Connectors
          # Renders reference relationship with dashed line and hollow arrow
          # (e.g., Element references another Element)
          class ReferenceConnector < ConnectorRenderer
            def initialize(config)
              super(config, "reference")
            end

            # Renders a reference connector
            # Dashed line with hollow arrow indicates reference
            def render(from_point, to_point)
              parts = []

              # Draw dashed line
              parts << create_line(
                from_point,
                to_point,
                dash_pattern: style.dash_pattern,
              )

              # Draw hollow triangle
              parts << create_hollow_triangle_at(to_point, from_point)

              parts.join("\n")
            end

            private

            def create_hollow_triangle_at(point, from_point)
              dir = direction(from_point, point)

              case dir
              when :down
                create_arrow_down(
                  point,
                  fill: "none",
                  stroke: config.colors.ui.border,
                  stroke_width: style.stroke_width,
                )
              when :up
                create_arrow_up(
                  point,
                  fill: "none",
                  stroke: config.colors.ui.border,
                  stroke_width: style.stroke_width,
                )
              else
                create_arrow_down(
                  point,
                  fill: "none",
                  stroke: config.colors.ui.border,
                  stroke_width: style.stroke_width,
                )
              end
            end
          end
        end
      end
    end
  end
end
