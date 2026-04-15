# frozen_string_literal: true

require_relative "path_builder"
require_relative "style_resolver"
require_relative "element_renderers/base_renderer"
require_relative "element_renderers/class_renderer"
require_relative "element_renderers/package_renderer"

module Lutaml
  module Ea
    module Diagram
      # Main SVG renderer for EA diagrams
      class SvgRenderer
        attr_reader :diagram_renderer, :options, :bounds, :style_resolver

        DEFAULT_OPTIONS = {
          padding: 20,
          background_color: "#ffffff",
          grid_visible: false,
          interactive: false,
          css_classes: [],
        }.freeze

        def initialize(diagram_renderer, options = {})
          @diagram_renderer = diagram_renderer
          @options = DEFAULT_OPTIONS.merge(options)
          @bounds = diagram_renderer.bounds
          @style_resolver = StyleResolver.new(options[:config_path])
        end

        # Render the complete SVG diagram
        # @return [String] Complete SVG content
        def render # rubocop:disable Metrics/AbcSize
          svg_content = +""
          svg_content << svg_header
          svg_content << defs_section
          svg_content << background_layer
          svg_content << grid_layer if options[:grid_visible]
          svg_content << connectors_layer
          svg_content << elements_layer
          svg_content << interactive_layer if options[:interactive]
          svg_content << svg_footer
          svg_content
        end

        private

        def svg_header # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          # Bounds already include padding from LayoutEngine
          width = bounds[:width]
          height = bounds[:height]

          # Normalize viewBox to start at 0,0 (matching EA export format)
          # Shift all content to positive coordinates
          offset_x = bounds[:x].negative? ? bounds[:x].abs : 0
          offset_y = bounds[:y].negative? ? bounds[:y].abs : 0
          total_width = width + offset_x
          total_height = height + offset_y

          view_box = "0 0 #{total_width} #{total_height}"

          # Format width/height in cm (matching EA export format)
          width_cm = format("%.2f", (total_width / 37.7952755906).round(2))
          height_cm = format("%.2f", (total_height / 37.7952755906).round(2))

          <<~SVG
            <?xml version="1.0" encoding="UTF-8" standalone="no"?>
            <!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.0//EN" "http://www.w3.org/TR/2001/REC-SVG-20010904/DTD/svg10.dtd">

            <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="#{width_cm}cm" height="#{height_cm}cm" viewBox="#{view_box}">
            <title></title>
            <desc>Created with Enterprise Architect (Build: 1624) 2</desc>
          SVG
        end

        def defs_section
          <<~SVG
            <defs>
              <style type="text/css">
                <![CDATA[
                .lutaml-diagram-element { cursor: pointer; }
                .lutaml-diagram-element:hover { opacity: 0.8; }
                .lutaml-diagram-connector { fill: none; stroke: #000000; stroke-width: 1; }
                .lutaml-diagram-connector:hover { stroke-width: 2; }
                .lutaml-diagram-grid { stroke: #e0e0e0; stroke-width: 0.5; }
                .lutaml-diagram-text { font-family: Arial, sans-serif; font-size: 11px; }
                .lutaml-diagram-stereotype { font-style: italic; font-size: 9px; }
                .lutaml-diagram-class-name { font-weight: bold; font-size: 12px; }
                ]]>
              </style>
              <!-- EA-style arrow markers -->
              <marker id="generalization-arrow" markerWidth="10" markerHeight="7"
                      refX="9" refY="3.5" orient="auto">
                <polygon points="0 0, 10 3.5, 0 7" fill="#FFFFFF" stroke="#000000" stroke-width="1" />
              </marker>
              <marker id="association-arrow" markerWidth="10" markerHeight="7"
                      refX="9" refY="3.5" orient="auto">
                <polygon points="0 0, 10 3.5, 0 7" fill="#000000" />
              </marker>
              <marker id="aggregation-arrow" markerWidth="12" markerHeight="12"
                      refX="6" refY="6" orient="auto">
                <polygon points="6,0 12,6 6,12 0,6" fill="#FFFFFF" stroke="#000000" stroke-width="1" />
              </marker>
              <marker id="composition-arrow" markerWidth="12" markerHeight="12"
                      refX="6" refY="6" orient="auto">
                <polygon points="6,0 12,6 6,12 0,6" fill="#000000" stroke="#000000" stroke-width="1" />
              </marker>
              <marker id="dependency-arrow" markerWidth="10" markerHeight="7"
                      refX="9" refY="3.5" orient="auto">
                <polygon points="0 0, 10 3.5, 0 7" fill="#000000" />
              </marker>
              <marker id="realization-arrow" markerWidth="10" markerHeight="7"
                      refX="9" refY="3.5" orient="auto">
                <polygon points="0 0, 10 3.5, 0 7" fill="#FFFFFF" stroke="#000000" stroke-width="1" />
              </marker>
            </defs>
          SVG
        end

        def background_layer # rubocop:disable Metrics/AbcSize
          offset_x = bounds[:x].negative? ? bounds[:x].abs : 0
          offset_y = bounds[:y].negative? ? bounds[:y].abs : 0
          total_width = bounds[:width] + offset_x
          total_height = bounds[:height] + offset_y

          <<~SVG
            <g style="fill:#{options[:background_color]};fill-opacity:1.00;">
                 <rect x="0" y="0" width="#{total_width}" height="#{total_height}" shape-rendering="auto"/>
            </g>
          SVG
        end

        def grid_layer # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          grid_size = 20
          grid_lines = +""

          # Vertical lines
          x = bounds[:x]
          while x <= bounds[:x] + bounds[:width]
            grid_lines << "<line x1=\"#{x}\" y1=\"#{bounds[:y]}\" " \
                          "x2=\"#{x}\" " \
                          "y2=\"#{bounds[:y] + bounds[:height]}\" " \
                          "class=\"lutaml-diagram-grid\" />\n"
            x += grid_size
          end

          # Horizontal lines
          y = bounds[:y]
          while y <= bounds[:y] + bounds[:height]
            grid_lines << "<line x1=\"#{bounds[:x]}\" y1=\"#{y}\" " \
                          "x2=\"#{bounds[:x] + bounds[:width]}\" " \
                          "y2=\"#{y}\" class=\"lutaml-diagram-grid\" />\n"
            y += grid_size
          end

          "<g id=\"grid-layer\" " \
            "class=\"lutaml-diagram-grid-layer\">\n#{grid_lines}</g>\n"
        end

        def connectors_layer
          connectors_svg = diagram_renderer.connectors.map do |connector|
            render_connector(connector)
          end.join("\n")

          "<g id=\"connectors-layer\" " \
            "class=\"lutaml-diagram-connectors-layer\">\n" \
            "#{connectors_svg}\n</g>\n"
        end

        def elements_layer
          elements_svg = diagram_renderer.elements.map do |element|
            render_element(element)
          end.join("\n")

          "<g id=\"elements-layer\" " \
            "class=\"lutaml-diagram-elements-layer\">\n#{elements_svg}\n</g>\n"
        end

        def interactive_layer
          # Add interactive JavaScript if needed
          <<~SVG
            <script type="text/javascript">
            <![CDATA[
              // Basic interactivity
              document.addEventListener('DOMContentLoaded', function() {
                var elements = document.querySelectorAll('.lutaml-diagram-element');
                elements.forEach(function(el) {
                  el.addEventListener('click', function(e) {
                    var event = new CustomEvent('lutaml:element:click', {
                      detail: {
                        elementId: e.target.getAttribute('data-element-id'),
                        elementType: e.target.getAttribute('data-element-type')
                      }
                    });
                    document.dispatchEvent(event);
                    console.log('Element clicked:', e.target.getAttribute('data-element-id'));
                  });
                });
              });
            ]]>
            </script>
          SVG
        end

        def svg_footer
          "</svg>\n"
        end

        def render_connector(connector) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          path_builder = PathBuilder.new(
            connector,
            connector[:source_element],
            connector[:target_element],
          )
          path_data = path_builder.build_path

          style = style_resolver.resolve_connector_style(connector)

          # Determine marker based on connector type
          markers = determine_marker_type(connector[:type])
          marker_start = markers[:start] || ""
          marker_end = markers[:end] || ""

          # Build style string
          style_attrs = []
          style_attrs << "stroke:#{style[:stroke] || '#000000'}"
          style_attrs << "stroke-width:#{style[:stroke_width] || '1'}"
          style_attrs << "stroke-linecap:#{style[:stroke_linecap] || 'round'}"
          style_attrs << "stroke-linejoin:#{style[:stroke_linejoin] || 'bevel'}"
          style_attrs << "fill:#{style[:fill] || 'none'}"
          style_attrs << "shape-rendering:#{style[:shape_rendering] || 'auto'}"
          if style[:stroke_dasharray]
            style_attrs << "stroke-dasharray:#{style[:stroke_dasharray]}"
          end

          <<~SVG
            <g style="#{style_attrs.join(';')}">
              <path d="#{path_data}"
                    class="lutaml-diagram-connector lutaml-diagram-connector-#{connector[:type]}"
                    data-connector-id="#{connector[:id]}"
                    data-connector-type="#{connector[:type]}"
                    #{"marker-start=\"#{marker_start}\"" unless marker_start.empty?}
                    #{"marker-end=\"#{marker_end}\"" unless marker_end.empty?}
                    shape-rendering="auto" />
            </g>
          SVG
        end

        def render_element(element)
          renderer_class = case element[:type]
                           when "class", "datatype" then ElementRenderers::ClassRenderer
                           when "package" then ElementRenderers::PackageRenderer
                           else ElementRenderers::BaseRenderer
                           end

          renderer = renderer_class.new(element, style_resolver)
          renderer.render
        end

        def determine_marker_type(connector_type) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/MethodLength
          normalized_type = connector_type.to_s.downcase

          case normalized_type
          when "generalization", "inheritance"
            { end: "url(#generalization-arrow)" }
          when "aggregation"
            { start: "url(#aggregation-arrow)" }
          when "composition"
            { start: "url(#composition-arrow)" }
          when "dependency"
            { end: "url(#dependency-arrow)" }
          when "realization", "implementation"
            { end: "url(#realization-arrow)" }
          else
            { end: "url(#association-arrow)" }
          end
        end

        def style_to_css(style_hash)
          style_hash.map { |k, v| "#{k}:#{v}" }.join(";")
        end
      end
    end
  end
end
