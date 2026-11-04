# frozen_string_literal: true

require_relative "../component_renderer"

module Lutaml
  module Xsd
    module Spa
      module Svg
        module Renderers
          # Renders model group components (sequence, choice, all)
          class GroupRenderer < ComponentRenderer
            def render(component_data, box)
              type = component_data["type"] || component_data["kind"]

              parts = []

              # Box
              fill = if config.effects.gradient_enabled?
                       "url(#groupGradient)"
                     else
                       config.colors.group.base
                     end

              parts << create_box(
                box,
                fill,
                stroke: config.colors.ui.border,
                stroke_width: 1,
              )

              # Text
              parts << Utils::SvgBuilder.text(
                box.center.x,
                box.y + config.dimensions.text_offset_y,
                type,
                {
                  fill: config.colors.ui.text,
                  "font-size" => 12,
                  "font-weight" => "bold",
                  "text-anchor" => "middle",
                },
              )

              Utils::SvgBuilder.group({ class: "group-box" }) { parts.join("\n") }
            end
          end
        end
      end
    end
  end
end
