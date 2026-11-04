# frozen_string_literal: true

require_relative "../connector_renderer"

module Lutaml
  module Xsd
    module Spa
      module Svg
        module Connectors
          # Renders containment relationship with solid triangle arrow
          # (e.g., Element has Type)
          class ContainmentConnector < ConnectorRenderer
            def initialize(config)
              super(config, "containment")
            end

            # Renders a containment connector
            # Solid triangle indicates "has-a" relationship
            def render(from_point, to_point)
              parts = []

              # Draw line
              parts << create_line(from_point, to_point)

              # Draw solid triangle at target
              parts << create_solid_triangle_at(to_point, from_point)

              parts.join("\n")
            end

            private

            def create_solid_triangle_at(point, from_point)
              dir = direction(from_point, point)

              case dir
              when :down
                create_arrow_down(point)
              when :up
                create_arrow_up(point)
              else
                create_arrow_down(point)
              end
            end
          end
        end
      end
    end
  end
end
