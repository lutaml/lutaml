# frozen_string_literal: true

require_relative "base_renderer"

module Lutaml
  module Ea
    module Diagram
      module ElementRenderers
        # Renderer for UML class elements
        class ClassRenderer < BaseRenderer
          protected

          def render_shape(style)
            x = element[:x] || 0
            y = element[:y] || 0
            width = element[:width] || 120
            height = element[:height] || 80

            # Calculate compartment heights
            name_height = 25
            attributes_height = calculate_attributes_height
            operations_height = calculate_operations_height

            total_height = name_height + attributes_height + operations_height

            # Adjust element height if needed
            height = [height, total_height].max

            # Build style string for the group
            group_style_attrs = []
            group_style_attrs << "stroke-width:#{style[:stroke_width] || 1}"
            group_style_attrs << "stroke-linecap:#{style[:stroke_linecap] || 'round'}"
            group_style_attrs << "stroke-linejoin:#{style[:stroke_linejoin] || 'bevel'}"
            group_style_attrs << "fill:#{style[:fill]}"
            group_style_attrs << "fill-opacity:#{style[:fill_opacity] || '1.00'}"
            group_style_attrs << "stroke:#{style[:stroke]}"
            group_style_attrs << "stroke-opacity:#{style[:stroke_opacity] || '1.00'}"

            # Build style string for compartment lines
            line_style_attrs = []
            line_style_attrs << "stroke-width:#{style[:compartment_width] || 1}"
            line_style_attrs << "stroke-linecap:#{style[:stroke_linecap] || 'round'}"
            line_style_attrs << "stroke-linejoin:#{style[:stroke_linejoin] || 'bevel'}"
            line_style_attrs << "fill:#000000"
            line_style_attrs << "fill-opacity:0.00"
            line_style_attrs << "stroke:#{style[:stroke]}"
            line_style_attrs << "stroke-opacity:#{style[:stroke_opacity] || '1.00'}"

            <<~SVG
              <g style="#{group_style_attrs.join(';')}">
               <rect x="#{x}"
                    y="#{y}"
                    width="#{width}"
                    height="#{height}"
                    rx="#{style[:rx] || 0.00}"
                    shape-rendering="#{style[:shape_rendering] || 'auto'}"  />
              </g>
              <g style="#{line_style_attrs.join(';')}">
              <!-- Name compartment -->
              <path d="M #{x} #{y + name_height} L #{x + width} #{y + name_height}" shape-rendering="#{style[:shape_rendering] || 'auto'}"/>

              <!-- Attributes compartment (if any) -->
              #{render_attributes_compartment_separator(x, y, width, name_height, attributes_height, style)}

              <!-- Operations compartment (if any) -->
              #{render_operations_compartment_separator(x, y, width, name_height, attributes_height, operations_height, style)}
              </g>
            SVG
          end

          def render_label(style)
            x = element[:x] || 0
            y = element[:y] || 0
            width = element[:width] || 120

            # Calculate compartment heights
            name_height = 25
            attributes_height = calculate_attributes_height
            operations_height = calculate_operations_height

            svg_content = String.new

            # Class name (centered in name compartment)
            name_y = y + name_height / 2 + 5
            svg_content << render_text_element(
              element[:name],
              x + width / 2,
              name_y,
              style,
              "lutaml-diagram-class-name",
              font_weight: style[:font_weight] || "700",
              font_style: style[:font_style] || "italic",
              font_family: style[:font_family] || "Cambria",
              font_size: style[:font_size] || "7pt"
            )

            # Stereotype (above name if present)
            if element[:stereotype]
              stereotype_y = y + 15
              svg_content << render_text_element(
                "«#{element[:stereotype]}»",
                x + width / 2,
                stereotype_y,
                style,
                "lutaml-diagram-class-stereotype",
                font_weight: style[:stereotype_font_weight] || "0",
                font_style: style[:stereotype_font_style] || "normal",
                font_family: style[:stereotype_font_family] || "Cambria",
                font_size: style[:stereotype_font_size] || "7pt"
              )
            end

            # Attributes
            if element[:attributes]&.any?
              attr_y = y + name_height + 15
              element[:attributes].each do |attr|
                svg_content << render_text_element(
                  format_attribute(attr),
                  x + 5,
                  attr_y,
                  style,
                  "lutaml-diagram-class-attribute",
                  font_weight: style[:attribute_font_weight] || "0",
                  font_style: style[:attribute_font_style] || "normal",
                  font_family: style[:attribute_font_family] || "Cambria",
                  font_size: style[:attribute_font_size] || "7pt",
                  text_anchor: "start"
                )
                attr_y += 15
              end
            end

            # Operations
            if element[:operations]&.any?
              op_y = y + name_height + attributes_height + 15
              element[:operations].each do |op|
                svg_content << render_text_element(
                  format_operation(op),
                  x + 5,
                  op_y,
                  style,
                  "lutaml-diagram-class-operation",
                  font_weight: style[:attribute_font_weight] || "0",
                  font_style: style[:attribute_font_style] || "normal",
                  font_family: style[:attribute_font_family] || "Cambria",
                  font_size: style[:attribute_font_size] || "7pt",
                  text_anchor: "start"
                )
                op_y += 15
              end
            end

            # Build text style string
            text_style_attrs = []
            text_style_attrs << "stroke-width:1"
            text_style_attrs << "stroke-linecap:round"
            text_style_attrs << "stroke-linejoin:bevel"
            text_style_attrs << "fill:#000000"
            text_style_attrs << "fill-opacity:1.00"
            text_style_attrs << "stroke:#000000"
            text_style_attrs << "stroke-opacity:0.00"

            "<g style=\"#{text_style_attrs.join(';')}\">\n#{svg_content}\n</g>"
          end

          private

          def calculate_attributes_height
            return 0 unless element[:attributes]&.any?
            element[:attributes].size * 15 + 10
          end

          def calculate_operations_height
            return 0 unless element[:operations]&.any?
            element[:operations].size * 15 + 10
          end

          def render_attributes_compartment_separator(x, y, width, name_height, attributes_height, style)
            return "" if attributes_height.zero?

            separator_y = y + name_height + attributes_height
            <<~SVG
              <path d="M #{x} #{separator_y} L #{x + width} #{separator_y}" shape-rendering="#{style[:shape_rendering] || 'auto'}"/>
            SVG
          end

          def render_operations_compartment_separator(x, y, width, name_height, attributes_height, operations_height, style)
            return "" if operations_height.zero?

            separator_y = y + name_height + attributes_height + operations_height
            <<~SVG
              <path d="M #{x} #{separator_y} L #{x + width} #{separator_y}" shape-rendering="#{style[:shape_rendering] || 'auto'}"/>
            SVG
          end

          def render_text_element(text, x, y, style, css_class, options = {})
            return "" unless text

            font_size = options[:font_size] || style[:font_size] || "7pt"
            font_weight = options[:font_weight] || style[:font_weight] || "0"
            font_style = options[:font_style] || style[:font_style] || "normal"
            font_family = options[:font_family] || style[:font_family] || "Cambria"
            fill_color = options[:fill] || style[:text_color] || "#000000"
            text_anchor = options[:text_anchor] || "middle"

            # Calculate text length approximation (EA uses this for precise positioning)
            text_length = calculate_text_length(text, font_size)

            # Build transform attribute if needed
            transform_attr = ""
            if options[:rotate] && options[:rotate] != 0
              transform_attr = "transform=\"rotate(#{options[:rotate]} #{x} #{y})\""
            end

            # Text stroke styling (EA uses this for text elements)
            text_stroke = options[:text_stroke] || style[:text_stroke] || "#000000"
            text_stroke_opacity = options[:text_stroke_opacity] || style[:text_stroke_opacity] || "0.00"
            text_stroke_width = options[:text_stroke_width] || style[:text_stroke_width] || "0"

            <<~SVG
              <text x="#{x}.00"
                    y="#{y}.00"
                    #{text_length > 0 ? "textLength=\"#{text_length}\"" : ""}
                    style="font-family:#{font_family}; font-weight:#{font_weight}; font-style:#{font_style}; font-size:#{font_size}; fill:#{fill_color};fill-opacity:1.00; stroke:#{text_stroke}; stroke-opacity:#{text_stroke_opacity} stroke-width:#{text_stroke_width}; white-space: pre;"
                    xml:space="preserve"
                    #{transform_attr}>
                #{escape_text(text)}
              </text>
            SVG
          end

          def format_attribute(attribute)
            return attribute unless attribute.is_a?(Hash)

            visibility = visibility_symbol(attribute[:visibility])
            name = attribute[:name] || ""
            type = attribute[:type] ? ": #{attribute[:type]}" : ""

            "#{visibility}#{name}#{type}"
          end

          def format_operation(operation)
            return operation unless operation.is_a?(Hash)

            visibility = visibility_symbol(operation[:visibility])
            name = operation[:name] || ""
            params = format_parameters(operation[:parameters] || [])
            return_type = operation[:return_type] ? ": #{operation[:return_type]}" : ""

            "#{visibility}#{name}(#{params})#{return_type}"
          end

          def format_parameters(parameters)
            parameters.map do |param|
              if param.is_a?(Hash)
                "#{param[:name]}: #{param[:type]}"
              else
                param.to_s
              end
            end.join(", ")
          end

          def visibility_symbol(visibility)
            case visibility&.to_s
            when "public" then "+"
            when "private" then "-"
            when "protected" then "#"
            when "package" then "~"
            else ""
            end
          end

          # Parse font size string to get numeric value
          def parse_font_size(font_size)
            return 7 if font_size.nil? # default size

            # Extract numeric part from font size string (e.g., "7pt" -> 7)
            if font_size.is_a?(String)
              match = font_size.match(/(\d+(?:\.\d+)?)/)
              match ? match[1].to_f : 7
            else
              font_size.to_f
            end
          end

          # Calculate approximate text length in pixels (EA uses this for precise positioning)
          def calculate_text_length(text, font_size)
            return 0 unless text

            # Simple approximation: average character width * text length
            # This is a rough approximation - in a real implementation, we'd use actual font metrics
            font_size_num = parse_font_size(font_size)
            text.to_s.length * (font_size_num * 0.6).to_i
          end
        end
      end
    end
  end
end