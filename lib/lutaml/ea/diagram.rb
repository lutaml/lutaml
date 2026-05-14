# frozen_string_literal: true

module Lutaml
  module Ea
    module Diagram
      autoload :SvgRenderer, "lutaml/ea/diagram/svg_renderer"
      autoload :LayoutEngine, "lutaml/ea/diagram/layout_engine"
      autoload :StyleParser, "lutaml/ea/diagram/style_parser"
      autoload :PathBuilder, "lutaml/ea/diagram/path_builder"
      autoload :StyleResolver, "lutaml/ea/diagram/style_resolver"
      autoload :Configuration, "lutaml/ea/diagram/configuration"
      autoload :Util, "lutaml/ea/diagram/util"
      autoload :Extractor, "lutaml/ea/diagram/extractor"
      autoload :ElementRenderers, "lutaml/ea/diagram/element_renderers"

      # Main entry point for diagram rendering
      class DiagramRenderer
        attr_reader :diagram_data, :layout_engine, :style_parser

        def initialize(diagram_data)
          @diagram_data = diagram_data
          @layout_engine = LayoutEngine.new
          @style_parser = StyleParser.new
        end

        # Render the complete diagram as SVG
        # @return [String] SVG content
        def render_svg(options = {})
          svg_renderer = SvgRenderer.new(self, options)
          svg_renderer.render
        end

        # Get diagram bounds for viewport calculation
        # @return [Hash] Bounds with x, y, width, height
        def bounds
          layout_engine.calculate_bounds(diagram_data)
        end

        # Get all elements in the diagram
        # @return [Array] Array of diagram elements
        def elements
          diagram_data[:elements] || []
        end

        # Get all connectors in the diagram
        # @return [Array] Array of connector elements
        def connectors
          diagram_data[:connectors] || []
        end
      end

      # Convenience method for rendering diagrams
      # @param diagram_data [Hash] EA diagram data
      # @param options [Hash] Rendering options
      # @return [String] SVG content
      def self.render(diagram_data, options = {})
        renderer = DiagramRenderer.new(diagram_data)
        renderer.render_svg(options)
      end
    end
  end
end
