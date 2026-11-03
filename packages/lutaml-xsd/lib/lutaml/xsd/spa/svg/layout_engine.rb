# frozen_string_literal: true

require_relative "geometry/box"
require_relative "geometry/point"

module Lutaml
  module Xsd
    module Spa
      module Svg
        # Abstract base class for layout engines
        # Subclasses must implement #calculate method
        class LayoutEngine
          attr_reader :config

          def initialize(config)
            @config = config
          end

          # Factory method to create appropriate layout engine
          def self.for(config)
            case config.layout_type
            when "tree"
              Lutaml::Xsd::Spa::Svg::Layouts::TreeLayout.new(config)
            when "vertical"
              Lutaml::Xsd::Spa::Svg::Layouts::VerticalLayout.new(config)
            else
              raise ArgumentError, "Unknown layout type: #{config.layout_type}"
            end
          end

          # Calculates layout for the given component data
          # @param component_data [Hash] The component data
          # @param component_type [Symbol] :element or :type
          # @return [LayoutResult] The calculated layout
          def calculate(component_data, component_type)
            raise NotImplementedError, "#{self.class} must implement #calculate"
          end

          protected

          # Creates a layout node
          def create_node(component, position, level = 0)
            box = Geometry::Box.new(
              position.x,
              position.y,
              config.dimensions.box_width,
              config.dimensions.box_height,
            )

            LayoutNode.new(
              component: component,
              box: box,
              level: level,
            )
          end
        end

        # Value object representing the result of layout calculation
        class LayoutResult
          attr_reader :nodes, :connections, :dimensions

          def initialize(nodes, connections, dimensions)
            @nodes = nodes
            @connections = connections
            @dimensions = dimensions
          end
        end

        # Value object representing a positioned layout node
        class LayoutNode
          attr_reader :component, :box, :level

          def initialize(component:, box:, level:)
            @component = component
            @box = box
            @level = level
          end
        end

        # Value object representing a connection between nodes
        class LayoutConnection
          attr_reader :from_node, :to_node, :connector_type

          def initialize(from_node, to_node, connector_type)
            @from_node = from_node
            @to_node = to_node
            @connector_type = connector_type
          end
        end
      end
    end
  end
end
