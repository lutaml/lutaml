# frozen_string_literal: true

require_relative "../component_renderer"

module Lutaml
  module Xsd
    module Spa
      module Svg
        module Renderers
          # Renders XSD type components (complexType, simpleType)
          class TypeRenderer < ComponentRenderer
            def render(component_data, box)
              name = component_data["name"]
              rule = config.component_rule("type")

              content = if rule.clickable?
                          create_link(semantic_uri("types", name)) do
                            render_box_and_text(box, name, rule, component_data)
                          end
                        else
                          render_box_and_text(box, name, rule, component_data)
                        end

              Utils::SvgBuilder.group({ class: "type-box" }) { content }
            end

            private

            def render_box_and_text(box, name, rule, component_data)
              parts = []

              # Box with gradient
              fill = if config.effects.gradient_enabled?
                       "url(#typeGradient)"
                     else
                       config.colors.type.base
                     end

              parts << create_box(
                box,
                fill,
                filter: rule.filter,
                stroke: config.colors.ui.border,
                stroke_width: 2,
              )

              # Text
              parts << create_centered_text(box, name)

              # Indicator if abstract
              if component_data["abstract"]
                parts << render_indicator("abstract",
                                          box)
              end

              parts.join("\n")
            end

            def render_indicator(type, box)
              indicator = config.indicator_rule(type)
              return "" unless indicator

              Utils::SvgBuilder.text(
                box.x + box.width + indicator.offset_x,
                box.y + indicator.offset_y,
                indicator.text,
                {
                  fill: config.colors.indicators.color_for(type),
                  "font-size" => config.dimensions.text_small_font_size,
                  "font-style" => indicator.style,
                  "text-anchor" => "end",
                },
              )
            end
          end
        end
      end
    end
  end
end
