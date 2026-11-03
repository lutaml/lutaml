# frozen_string_literal: true

require_relative "../layout_engine"

module Lutaml
  module Xsd
    module Spa
      module Svg
        module Layouts
          # Simple vertical layout - stacks components vertically
          class VerticalLayout < LayoutEngine
            def calculate(component_data, _component_type)
              nodes = []
              connections = []

              start_x = 20
              start_y = 20
              current_y = start_y

              # Main component node
              main_node = create_node(
                component_data,
                Geometry::Point.new(start_x, current_y),
                0,
              )
              nodes << main_node
              current_y += config.dimensions.box_height +
                config.dimensions.spacing_vertical

              # Add type reference if present
              if component_data["type"]
                type_node = create_node(
                  { "name" => component_data["type"], "kind" => "type" },
                  Geometry::Point.new(start_x, current_y),
                  1,
                )
                nodes << type_node
                connections << LayoutConnection.new(
                  main_node,
                  type_node,
                  "containment",
                )
                current_y += config.dimensions.box_height +
                  config.dimensions.spacing_vertical
              end

              # Add attributes
              if component_data["attributes"]&.any?
                component_data["attributes"].each do |attr|
                  attr_node = create_node(
                    attr.merge("kind" => "attribute"),
                    Geometry::Point.new(
                      start_x + config.dimensions.spacing_indent,
                      current_y,
                    ),
                    1,
                  )
                  nodes << attr_node
                  current_y += config.dimensions.box_height +
                    config.dimensions.spacing_vertical
                end
              end

              # Calculate total dimensions
              max_y = current_y + 20
              width = config.dimensions.box_width + 40

              LayoutResult.new(
                nodes,
                connections,
                Geometry::Box.new(0, 0, width, max_y),
              )
            end
          end
        end
      end
    end
  end
end
