# frozen_string_literal: true

require_relative "../layout_engine"

module Lutaml
  module Xsd
    module Spa
      module Svg
        module Layouts
          # Tree-based layout - organizes components hierarchically
          class TreeLayout < LayoutEngine
            def calculate(component_data, component_type)
              nodes = []
              connections = []

              start_x = 20
              start_y = 20

              # Build tree structure
              tree = build_tree(component_data, component_type)

              # Calculate positions
              position_tree(tree, start_x, start_y, nodes, connections)

              # Calculate dimensions
              max_x = nodes.map { |n| n.box.x + n.box.width }.max || 200
              max_y = nodes.map { |n| n.box.y + n.box.height }.max || 100

              LayoutResult.new(
                nodes,
                connections,
                Geometry::Box.new(0, 0, max_x + 20, max_y + 20),
              )
            end

            private

            def build_tree(component_data, component_type)
              {
                data: component_data,
                type: component_type,
                children: build_children(component_data),
              }
            end

            def build_children(component_data)
              children = []

              # Add type as child if present
              if component_data["type"]
                children << {
                  data: { "name" => component_data["type"], "kind" => "type" },
                  type: :type,
                  children: [],
                  connector_type: "containment",
                }
              end

              # Add base type if present
              if component_data["base_type"]
                children << {
                  data: {
                    "name" => component_data["base_type"],
                    "kind" => "type",
                  },
                  type: :type,
                  children: [],
                  connector_type: "inheritance",
                }
              end

              # Add attributes
              if component_data["attributes"]&.any?
                component_data["attributes"].each do |attr|
                  children << {
                    data: attr.merge("kind" => "attribute"),
                    type: :attribute,
                    children: [],
                    connector_type: "containment",
                  }
                end
              end

              # Add content model elements
              if component_data["content_model"].is_a?(Hash)
                elements = component_data["content_model"]["elements"] || []
                elements.each do |elem|
                  children << {
                    data: elem.merge("kind" => "element"),
                    type: :element,
                    children: [],
                    connector_type: "containment",
                  }
                end
              end

              children
            end

            def position_tree(tree, x, y, nodes, connections,
                              level = 0, parent_node = nil)
              # Create node for this item
              node = create_node(
                tree[:data],
                Geometry::Point.new(x, y),
                level,
              )
              nodes << node

              # Create connection to parent if exists
              if parent_node
                connector_type = tree[:connector_type] || "containment"
                connections << LayoutConnection.new(
                  parent_node,
                  node,
                  connector_type,
                )
              end

              # Position children
              return if tree[:children].empty?

              child_x = x + config.dimensions.spacing_indent
              child_y = y + config.dimensions.box_height +
                config.dimensions.spacing_vertical

              tree[:children].each do |child|
                position_tree(
                  child,
                  child_x,
                  child_y,
                  nodes,
                  connections,
                  level + 1,
                  node,
                )
                child_y += config.dimensions.box_height +
                  config.dimensions.spacing_vertical
              end
            end
          end
        end
      end
    end
  end
end
