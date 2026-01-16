# frozen_string_literal: true

require_relative "base_renderer"

module Lutaml
  module Ea
    module Diagram
      module ElementRenderers
        # Renderer for UML package elements
        class PackageRenderer < BaseRenderer
          protected

          def render_shape(style) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity
            x = element[:x] || 0
            y = element[:y] || 0
            width = element[:width] || 120
            height = element[:height] || 80

            # Package tab height
            tab_height = 20

            # Draw package shape with tab
            <<~SVG
              <!-- Main package body -->
              <polygon points="#{x},#{y + tab_height} #{x + width},#{y + tab_height} #{x + width},#{y + height} #{x},#{y + height}"
                       fill="#{style[:fill]}"
                       stroke="#{style[:stroke]}"
                       stroke-width="#{style[:stroke_width] || 2}"
                       class="lutaml-diagram-package-shape" />

              <!-- Package tab -->
              <polygon points="#{x + 10},#{y + tab_height} #{x + 50},#{y + tab_height} #{x + 50},#{y} #{x + 10},#{y}"
                       fill="#{style[:fill]}"
                       stroke="#{style[:stroke]}"
                       stroke-width="#{style[:stroke_width] || 2}"
                       class="lutaml-diagram-package-tab" />
            SVG
          end

          def render_label(style) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity
            x = element[:x] || 0
            y = element[:y] || 0
            element[:width] || 120
            element[:height] || 80

            # Package name positioned in the tab area
            tab_height = 20
            text_x = x + 30 # Center in the tab
            text_y = y + (tab_height / 2) + 5

            <<~SVG
              <text x="#{text_x}"
                    y="#{text_y}"
                    text-anchor="middle"
                    dominant-baseline="middle"
                    font-family="#{style[:font_family]}"
                    font-size="#{style[:font_size]}"
                    font-weight="#{style[:font_weight] || 'bold'}"
                    fill="#{style[:text_color] || '#000000'}"
                    class="lutaml-diagram-package-name">
                #{escape_text(element[:name])}
              </text>
            SVG
          end
        end
      end
    end
  end
end