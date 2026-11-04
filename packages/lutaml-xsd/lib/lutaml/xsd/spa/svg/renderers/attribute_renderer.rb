# frozen_string_literal: true

require_relative "../component_renderer"

module Lutaml
  module Xsd
    module Spa
      module Svg
        module Renderers
          # Renders XSD attribute components
          class AttributeRenderer < ComponentRenderer
            def render(component_data, box)
              name = component_data["name"]
              type = component_data["type"]

              parts = []

              # Box
              fill = if config.effects.gradient_enabled?
                       "url(#attributeGradient)"
                     else
                       config.colors.attribute.base
                     end

              parts << create_box(
                box,
                fill,
                stroke: config.colors.ui.border,
                stroke_width: 1,
              )

              # Attribute name with @ prefix
              parts << Utils::SvgBuilder.text(
                box.x + 5,
                box.y + 15,
                "@#{name}",
                {
                  fill: "white",
                  "font-size" => 12,
                },
              )

              # Type on second line if present
              if type
                parts << Utils::SvgBuilder.text(
                  box.x + 5,
                  box.y + 27,
                  type,
                  {
                    fill: "white",
                    "font-size" => 10,
                    opacity: 0.8,
                  },
                )
              end

              # Required indicator
              parts << render_required_indicator(box) if component_data["use"] == "required"

              Utils::SvgBuilder.group({ class: "attribute-box" }) { parts.join("\n") }
            end

            private

            def render_required_indicator(box)
              Utils::SvgBuilder.text(
                box.x + box.width + 5,
                box.y + 15,
                "*",
                {
                  fill: config.colors.indicators.required,
                  "font-size" => config.dimensions.text_font_size,
                  "font-weight" => "bold",
                },
              )
            end
          end
        end
      end
    end
  end
end
