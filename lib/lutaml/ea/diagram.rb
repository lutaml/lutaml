# frozen_string_literal: true

require_relative "diagram/svg_renderer"
require_relative "diagram/layout_engine"
require_relative "diagram/style_parser"
require_relative "diagram/path_builder"
require_relative "diagram/element_renderers/base_renderer"
require_relative "diagram/element_renderers/class_renderer"
require_relative "diagram/element_renderers/package_renderer"
require_relative "diagram/element_renderers/connector_renderer"

module Lutaml
  module Ea
    # Diagram rendering module for converting EA diagrams to SVG
    #
    # This module provides comprehensive diagram rendering capabilities
    # for Enterprise Architect UML diagrams, converting them to clean,
    # interactive SVG format for web display.
    #
    # Key Features:
    # - SVG rendering with proper layout and styling
    # - Support for classes, packages, and connectors
    # - EA-specific style parsing and conversion
    # - Interactive elements with hover effects
    # - Path calculation for complex connector routing
    #
    # Usage:
    #   diagram = Lutaml::Ea::Diagram.new(ea_diagram_data)
    #   svg_content = diagram.render_svg
    module Diagram
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
