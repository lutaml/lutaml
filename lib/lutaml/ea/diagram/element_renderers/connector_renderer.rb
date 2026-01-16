# frozen_string_literal: true

require_relative "base_renderer"

module Lutaml
  module Ea
    module Diagram
      module ElementRenderers
        # Renderer for connector elements (relationships)
        class ConnectorRenderer < BaseRenderer
          attr_reader :source_element, :target_element

          def initialize( # rubocop:disable Lint/MissingSuper
            connector, style_parser, source_element = nil,
            target_element = nil
          )
            @element = connector
            @style_parser = style_parser
            @source_element = source_element
            @target_element = target_element
          end

          # Render the connector as SVG path
          # @return [String] SVG content for the connector
          def render
            path_builder = PathBuilder.new(@element, source_element,
                                           target_element)
            path_data = path_builder.build_path

            style = style_parser.parse_connector_style(@element)

            # Add connector type class
            css_classes = ["lutaml-diagram-connector",
                           "lutaml-diagram-connector-#{@element[:type]}"]

            <<~SVG
              <path d="#{path_data}"
                    class="#{css_classes.join(' ')}"
                    style="#{style_to_css(style)}"
                    data-connector-id="#{@element[:id]}"
                    data-connector-type="#{@element[:type]}"
                    marker-end="url(#arrowhead)" />
            SVG
          end

          private

          def style_to_css(style_hash)
            style_hash.map { |k, v| "#{k}:#{v}" }.join(";")
          end
        end
      end
    end
  end
end