# frozen_string_literal: true

require_relative "../connector_renderer"

module Lutaml
  module Xsd
    module Spa
      module Svg
        module Connectors
          # Renders inheritance relationship with hollow triangle arrow
          # (e.g., Type extends BaseType)
          class InheritanceConnector < ConnectorRenderer
            def initialize(config)
              super(config, "inheritance")
            end

            # Renders an inheritance connector from parent to child
            # Hollow triangle indicates "extends" relationship
            def render(from_point, to_point)
              parts = []

              # Draw line from parent to child
              parts << create_line(from_point, to_point)

              # Draw hollow triangle at child end
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
                  fill: "white",
                  stroke: config.colors.ui.border,
                  stroke_width: style.stroke_width,
                )
              when :up
                create_arrow_up(
                  point,
                  fill: "white",
                  stroke: config.colors.ui.border,
                  stroke_width: style.stroke_width,
                )
              else
                # For horizontal, use down arrow (most common case)
                create_arrow_down(
                  point,
                  fill: "white",
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
