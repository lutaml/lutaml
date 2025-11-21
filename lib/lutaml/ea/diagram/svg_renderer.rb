# frozen_string_literal: true

require_relative "element_renderers/base_renderer"

module Lutaml
  module Ea
    module Diagram
      # Main SVG renderer for EA diagrams
      class SvgRenderer
        attr_reader :diagram_renderer, :options, :bounds

        DEFAULT_OPTIONS = {
          padding: 20,
          background_color: "#ffffff",
          grid_visible: false,
          interactive: true,
          css_classes: []
        }.freeze

        def initialize(diagram_renderer, options = {})
          @diagram_renderer = diagram_renderer
          @options = DEFAULT_OPTIONS.merge(options)
          @bounds = diagram_renderer.bounds
        end

        # Render the complete SVG diagram
        # @return [String] Complete SVG content
        def render
          svg_content = String.new
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

        def svg_header
          width = bounds[:width] + (options[:padding] * 2)
          height = bounds[:height] + (options[:padding] * 2)
          view_box = "#{bounds[:x] - options[:padding]} #{bounds[:y] - options[:padding]} #{width} #{height}"

          css_classes = ["lutaml-diagram-svg"] + Array(options[:css_classes])

          <<~SVG
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.0//EN" "http://www.w3.org/TR/2001/REC-SVG-20010904/DTD/svg10.dtd">
            <svg xmlns="http://www.w3.org/2000/svg"
                 xmlns:xlink="http://www.w3.org/1999/xlink"
                 version="1.0"
                 width="#{width}cm"
                 height="#{height}cm"
                 viewBox="#{view_box}"
                 class="#{css_classes.join(' ')}">
            <title></title>
            <desc>Created with LutaML EA Diagram Renderer</desc>
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
                ]]>
              </style>
              <!-- Arrow markers for connectors -->
              <marker id="arrowhead" markerWidth="10" markerHeight="7"
                      refX="9" refY="3.5" orient="auto">
                <polygon points="0 0, 10 3.5, 0 7" fill="#000000" />
              </marker>
              <marker id="diamond" markerWidth="12" markerHeight="12"
                      refX="6" refY="6" orient="auto">
                <polygon points="6,0 12,6 6,12 0,6" fill="#FFFFFF" stroke="#000000" stroke-width="1" />
              </marker>
              <marker id="filled-diamond" markerWidth="12" markerHeight="12"
                      refX="6" refY="6" orient="auto">
                <polygon points="6,0 12,6 6,12 0,6" fill="#000000" stroke="#000000" stroke-width="1" />
              </marker>
            </defs>
          SVG
        end

        def background_layer
          <<~SVG
            <g style="fill:#{options[:background_color]};fill-opacity:1.00;">
              <rect x="#{bounds[:x] - options[:padding]}"
                    y="#{bounds[:y] - options[:padding]}"
                    width="#{bounds[:width] + (options[:padding] * 2)}"
                    height="#{bounds[:height] + (options[:padding] * 2)}"
                    shape-rendering="auto"
                    class="lutaml-diagram-background" />
            </g>
          SVG
        end

        def grid_layer
          grid_size = 20
          grid_lines = String.new

          # Vertical lines
          x = bounds[:x]
          while x <= bounds[:x] + bounds[:width]
            grid_lines << %(<line x1="#{x}" y1="#{bounds[:y]}" x2="#{x}" y2="#{bounds[:y] + bounds[:height]}" class="lutaml-diagram-grid" />\n)
            x += grid_size
          end

          # Horizontal lines
          y = bounds[:y]
          while y <= bounds[:y] + bounds[:height]
            grid_lines << %(<line x1="#{bounds[:x]}" y1="#{y}" x2="#{bounds[:x] + bounds[:width]}" y2="#{y}" class="lutaml-diagram-grid" />\n)
            y += grid_size
          end

          "<g class=\"lutaml-diagram-grid-layer\">\n#{grid_lines}</g>\n"
        end

        def connectors_layer
          connectors_svg = diagram_renderer.connectors.map do |connector|
            render_connector(connector)
          end.join("\n")

          "<g class=\"lutaml-diagram-connectors-layer\">\n#{connectors_svg}\n</g>\n"
        end

        def elements_layer
          elements_svg = diagram_renderer.elements.map do |element|
            render_element(element)
          end.join("\n")

          "<g class=\"lutaml-diagram-elements-layer\">\n#{elements_svg}\n</g>\n"
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

        def render_connector(connector)
          path_builder = PathBuilder.new(connector)
          path_data = path_builder.build_path

          style = diagram_renderer.style_parser.parse_connector_style(connector)

          # Determine marker based on connector type
          marker_start = ""
          marker_end = "url(#arrowhead)"

          case connector[:type]
          when "generalization"
            marker_end = "url(#arrowhead)"
          when "aggregation"
            marker_start = "url(#diamond)"
            marker_end = ""
          when "composition"
            marker_start = "url(#filled-diamond)"
            marker_end = ""
          when "dependency"
            marker_end = "url(#arrowhead)"
          end

          # Build style string
          style_attrs = []
          style_attrs << "stroke:#{style[:stroke] || '#000000'}"
          style_attrs << "stroke-width:#{style[:stroke_width] || '1'}"
          style_attrs << "stroke-linecap:#{style[:stroke_linecap] || 'round'}"
          style_attrs << "stroke-linejoin:#{style[:stroke_linejoin] || 'bevel'}"
          style_attrs << "fill:#{style[:fill] || 'none'}"
          style_attrs << "shape-rendering:#{style[:shape_rendering] || 'auto'}"
          style_attrs << "stroke-dasharray:#{style[:stroke_dasharray]}" if style[:stroke_dasharray]

          <<~SVG
            <g style="#{style_attrs.join(';')}">
              <path d="#{path_data}"
                    class="lutaml-diagram-connector lutaml-diagram-connector-#{connector[:type]}"
                    data-connector-id="#{connector[:id]}"
                    data-connector-type="#{connector[:type]}"
                    #{marker_start.empty? ? "" : "marker-start=\"#{marker_start}\""}
                    #{marker_end.empty? ? "" : "marker-end=\"#{marker_end}\""}
                    shape-rendering="auto" />
            </g>
          SVG
        end

        def render_element(element)
          renderer_class = case element[:type]
                           when "class" then ElementRenderers::ClassRenderer
                           when "package" then ElementRenderers::PackageRenderer
                           else ElementRenderers::BaseRenderer
                           end

          renderer = renderer_class.new(element, diagram_renderer.style_parser)
          renderer.render
        end

        def style_to_css(style_hash)
          style_hash.map { |k, v| "#{k}:#{v}" }.join(";")
        end
      end
    end
  end
end