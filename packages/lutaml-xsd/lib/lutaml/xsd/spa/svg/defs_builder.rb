# frozen_string_literal: true

module Lutaml
  module Xsd
    module Spa
      module Svg
        # Builds SVG <defs> section with gradients, filters, and icons
        class DefsBuilder
          attr_reader :config

          def initialize(config)
            @config = config
          end

          def build
            parts = []
            parts << build_gradients if config.effects.gradient_enabled?
            parts << build_filters if config.effects.shadow_enabled?
            parts << build_icons

            "<defs>\n#{parts.join("\n")}\n</defs>"
          end

          private

          def build_gradients
            [
              build_gradient("elementGradient", config.colors.element),
              build_gradient("typeGradient", config.colors.type),
              build_gradient("attributeGradient", config.colors.attribute),
              build_gradient("groupGradient", config.colors.group),
            ].join("\n")
          end

          def build_gradient(id, colors)
            <<~SVG
              <linearGradient id="#{id}" x1="0%" y1="0%" x2="0%" y2="100%">
                <stop offset="0%" style="stop-color:#{colors.gradient_start};stop-opacity:1" />
                <stop offset="100%" style="stop-color:#{colors.gradient_end};stop-opacity:1" />
              </linearGradient>
            SVG
          end

          def build_filters
            <<~SVG
              <filter id="dropShadow" x="-50%" y="-50%" width="200%" height="200%">
                <feGaussianBlur in="SourceAlpha" stdDeviation="#{config.effects.shadow_blur}"/>
                <feOffset dx="#{config.effects.shadow_offset_x}" dy="#{config.effects.shadow_offset_y}" result="offsetblur"/>
                <feComponentTransfer>
                  <feFuncA type="linear" slope="#{config.effects.shadow_opacity}"/>
                </feComponentTransfer>
                <feMerge>
                  <feMergeNode/>
                  <feMergeNode in="SourceGraphic"/>
                </feMerge>
              </filter>
            SVG
          end

          def build_icons
            icon_size = config.dimensions.text_icon_size

            <<~SVG
              <!-- Element icon -->
              <g id="elementIcon">
                <rect x="0" y="0" width="#{icon_size}" height="#{icon_size}" fill="#{config.colors.element.base}" rx="2"/>
                <text x="#{icon_size / 2}" y="#{icon_size * 0.75}" fill="white" font-size="#{icon_size * 0.75}" font-weight="bold" text-anchor="middle">E</text>
              </g>

              <!-- Type icon -->
              <g id="typeIcon">
                <rect x="0" y="0" width="#{icon_size}" height="#{icon_size}" fill="#{config.colors.type.base}" rx="2"/>
                <text x="#{icon_size / 2}" y="#{icon_size * 0.75}" fill="white" font-size="#{icon_size * 0.75}" font-weight="bold" text-anchor="middle">T</text>
              </g>

              <!-- Attribute icon -->
              <g id="attributeIcon">
                <circle cx="#{icon_size / 2}" cy="#{icon_size / 2}" r="#{(icon_size / 2) - 1}" fill="#{config.colors.attribute.base}"/>
                <text x="#{icon_size / 2}" y="#{icon_size * 0.75}" fill="white" font-size="#{icon_size * 0.75}" font-weight="bold" text-anchor="middle">@</text>
              </g>
            SVG
          end
        end
      end
    end
  end
end
