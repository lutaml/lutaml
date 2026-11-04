# frozen_string_literal: true

require_relative "style_configuration"
require_relative "layout_engine"
require_relative "document_builder"
require_relative "renderers/element_renderer"
require_relative "renderers/type_renderer"
require_relative "renderers/attribute_renderer"
require_relative "renderers/group_renderer"
require_relative "connectors/inheritance_connector"
require_relative "connectors/containment_connector"
require_relative "connectors/reference_connector"

module Lutaml
  module Xsd
    module Spa
      module Svg
        # Main orchestrator for SVG diagram generation
        # Coordinates layout, rendering, and document assembly
        class DiagramGenerator
          attr_reader :config, :schema_name

          def initialize(schema_name, config = nil)
            @schema_name = schema_name
            @config = config || StyleConfiguration.load
            @layout_engine = LayoutEngine.for(@config)
            @document_builder = DocumentBuilder.new(@config)
            @renderers = build_renderers
            @connectors = build_connectors
          end

          # Generates SVG diagram for an element
          def generate_element_diagram(element_data)
            generate_diagram(element_data, :element)
          end

          # Generates SVG diagram for a type
          def generate_type_diagram(type_data)
            generate_diagram(type_data, :type)
          end

          private

          def generate_diagram(component_data, component_type)
            # 1. Calculate layout
            layout = @layout_engine.calculate(component_data, component_type)

            # 2. Render all components
            components = render_layout(layout)

            # 3. Build final SVG document
            @document_builder.build(components, layout.dimensions)
          rescue StandardError => e
            # Graceful error handling with fallback
            build_error_svg(e.message)
          end

          def render_layout(layout)
            rendered = []

            # Render all nodes
            layout.nodes.each do |node|
              renderer = get_renderer(node.component)
              rendered << renderer.render(node.component, node.box)
            end

            # Render all connections
            layout.connections.each do |connection|
              connector = get_connector(connection.connector_type)
              from_point = connection.from_node.box.bottom_center
              to_point = connection.to_node.box.top_center
              rendered << connector.render(from_point, to_point)
            end

            rendered
          end

          def get_renderer(component_data)
            kind = component_data["kind"] || infer_kind(component_data)

            @renderers[kind] || @renderers["element"]
          end

          def get_connector(connector_type)
            @connectors[connector_type] || @connectors["containment"]
          end

          def infer_kind(component_data)
            if component_data["type"] && !component_data["elements"]
              "element"
            elsif component_data["base_type"] || component_data["content_model"]
              "type"
            elsif component_data["use"]
              "attribute"
            else
              "element"
            end
          end

          def build_renderers
            {
              "element" => Renderers::ElementRenderer.new(@config,
                                                          @schema_name),
              "type" => Renderers::TypeRenderer.new(@config, @schema_name),
              "attribute" => Renderers::AttributeRenderer.new(@config,
                                                              @schema_name),
              "group" => Renderers::GroupRenderer.new(@config, @schema_name),
            }
          end

          def build_connectors
            {
              "inheritance" => Connectors::InheritanceConnector.new(@config),
              "containment" => Connectors::ContainmentConnector.new(@config),
              "reference" => Connectors::ReferenceConnector.new(@config),
            }
          end

          def build_error_svg(message)
            <<~SVG
              <svg xmlns="http://www.w3.org/2000/svg" width="800" height="900" viewBox="0 0 800 900">
                <rect x="10" y="10" width="280" height="80" fill="#ffcccc" stroke="#cc0000" stroke-width="2" rx="5"/>
                <text x="150" y="55" fill="#cc0000" font-size="12" text-anchor="middle">Error: #{Utils::SvgBuilder.escape_xml(message)}</text>
              </svg>
            SVG
          end
        end
      end
    end
  end
end
