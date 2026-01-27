# frozen_string_literal: true

module Lutaml
  module Ea
    module Diagram
      # Style parser for EA diagram formats
      # - matches Enterprise Architect's exact visual style
      #
      # This parser converts EA-specific style information into
      # CSS-compatible properties that exactly match EA's visual output.
      class StyleParser
        # EA's exact color scheme from real SVG analysis
        EA_COLORS = {
          # Element background colors
          class_fill: "#FFFFCC",           # Light yellow for classes
          datatype_fill: "#FFCCFF",        # Light pink for data types
          type_fill: "#CCFFCC",            # Light green for types
          package_fill: "#FFFFFF",         # White for packages
          enumeration_fill: "#FFFFCC",     # Same as classes
          interface_fill: "#FFFFCC",       # Same as classes

          # Text colors
          text_normal: "#000000",          # Black for normal text
          text_italic: "#000000",          # Black for italic text
          text_bold: "#000000",            # Black for bold text
          # Dark blue for small text (like in legend)
          text_small: "#003060",

          # Border colors
          border_normal: "#000000",        # Black borders
          border_compartment: "#000000",   # Black compartment lines

          # Background
          diagram_background: "#FFFFFF", # Pure white background

          # Special colors for different element types
          legend_gml: "#A0FFC0",           # Light green for GML legend
          legend_citygml: "#FFFFCC",       # Light yellow for CityGML legend
          # Dark blue background for legend text
          legend_text_background: "#003060",
        }.freeze

        # EA's exact typography from real SVG analysis
        EA_TYPOGRAPHY = {
          # Font families
          primary_font: "Cambria",
          secondary_font: "Carlito",

          # Font sizes (in points)
          normal_size: "7pt",
          small_size: "7pt",
          stereotype_size: "7pt",
          class_name_size: "7pt",
          attribute_size: "7pt",

          # Font weights
          normal_weight: "0",
          bold_weight: "700",

          # Font styles
          normal_style: "normal",
          italic_style: "italic",
        }.freeze

        # EA's exact stroke styling
        EA_STROKES = {
          border_width: "1",               # Main element borders
          compartment_width: "1",          # Compartment separator lines
          connector_width: "1",            # Connector lines

          # Line styling
          linecap: "round",
          linejoin: "bevel",
          shape_rendering: "auto",
        }.freeze

        # Parse element style from EA data to match EA's exact visual output
        # @param element [Hash] EA element data
        # @return [Hash] CSS-compatible style properties that match EA exactly
        def parse_element_style(element) # rubocop:disable Metrics/MethodLength
          base_style = get_base_element_style(element[:type])

          # Apply EA-specific style overrides based on element analysis
          style = base_style.dup

          # Parse EA style string if present (EA uses specific format)
          if element[:style]
            ea_style = parse_ea_style_string(element[:style])
            style.merge!(ea_style)
          end

          # Apply stereotype-specific styling
          # (EA has specific colors for stereotypes)
          if element[:stereotype]
            style.merge!(stereotype_style(element[:stereotype]))
          end

          # Apply element-specific EA styling
          style.merge!(element_specific_style(element))

          style
        end

        # Parse connector style from EA data to match EA's exact visual output
        # @param connector [Hash] EA connector data
        # @return [Hash] CSS-compatible style properties that match EA exactly
        def parse_connector_style(connector) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          base_style = {
            stroke: EA_COLORS[:border_normal],
            stroke_width: EA_STROKES[:connector_width],
            stroke_linecap: EA_STROKES[:linecap],
            stroke_linejoin: EA_STROKES[:linejoin],
            fill: "none",
            shape_rendering: EA_STROKES[:shape_rendering],
          }

          # Apply connector type specific styling (EA has different styles for
          # different connectors)
          case connector[:type]
          when "generalization"
            base_style[:stroke_dasharray] = "5,5"
          when "aggregation"
            base_style[:stroke] = "#666666"
            base_style[:stroke_dasharray] = "10,5"
          when "composition"
            base_style[:stroke] = "#333333"
            base_style[:stroke_dasharray] = "10,5"
          when "dependency"
            base_style[:stroke] = "#999999"
            base_style[:stroke_dasharray] = "2,2"
          end

          # Parse EA style string if present
          if connector[:style]
            ea_style = parse_ea_style_string(connector[:style])
            base_style.merge!(ea_style)
          end

          base_style
        end

        private

        def get_base_element_style(element_type) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          case element_type&.to_s
          when "package"
            {
              fill: EA_COLORS[:package_fill],
              stroke: EA_COLORS[:border_normal],
              stroke_width: EA_STROKES[:border_width],
              stroke_linecap: EA_STROKES[:linecap],
              stroke_linejoin: EA_STROKES[:linejoin],
              shape_rendering: EA_STROKES[:shape_rendering],
              rx: "0.00",
              fill_opacity: "1.00",
              stroke_opacity: "1.00",
            }
          when "datatype"
            {
              fill: EA_COLORS[:datatype_fill],
              stroke: EA_COLORS[:border_normal],
              stroke_width: EA_STROKES[:border_width],
              stroke_linecap: EA_STROKES[:linecap],
              stroke_linejoin: EA_STROKES[:linejoin],
              shape_rendering: EA_STROKES[:shape_rendering],
              rx: "0.00",
              fill_opacity: "1.00",
              stroke_opacity: "1.00",
            }
          when "enumeration"
            {
              fill: EA_COLORS[:enumeration_fill],
              stroke: EA_COLORS[:border_normal],
              stroke_width: EA_STROKES[:border_width],
              stroke_linecap: EA_STROKES[:linecap],
              stroke_linejoin: EA_STROKES[:linejoin],
              shape_rendering: EA_STROKES[:shape_rendering],
              rx: "0.00",
              fill_opacity: "1.00",
              stroke_opacity: "1.00",
            }
          else
            {
              fill: EA_COLORS[:class_fill],
              stroke: EA_COLORS[:border_normal],
              stroke_width: EA_STROKES[:border_width],
              stroke_linecap: EA_STROKES[:linecap],
              stroke_linejoin: EA_STROKES[:linejoin],
              shape_rendering: EA_STROKES[:shape_rendering],
              rx: "0.00", # EA uses sharp corners, not rounded
              fill_opacity: "1.00",
              stroke_opacity: "1.00",
            }
          end
        end

        def element_specific_style(element) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          style = {}

          # EA uses specific text styling based on element content
          if element[:name]
            # Class names are typically bold and italic in EA
            style[:font_family] = EA_TYPOGRAPHY[:primary_font]
            if element[:type] == "class"
              style[:font_size] = EA_TYPOGRAPHY[:class_name_size]
              style[:font_weight] = EA_TYPOGRAPHY[:bold_weight]
              style[:font_style] = EA_TYPOGRAPHY[:italic_style]
            else
              style[:font_size] = EA_TYPOGRAPHY[:normal_size]
              style[:font_weight] = EA_TYPOGRAPHY[:normal_weight]
              style[:font_style] = EA_TYPOGRAPHY[:normal_style]
            end
          end

          # Stereotype text styling
          if element[:stereotype]
            style[:stereotype_font_family] = EA_TYPOGRAPHY[:primary_font]
            style[:stereotype_font_size] = EA_TYPOGRAPHY[:stereotype_size]
            style[:stereotype_font_weight] = EA_TYPOGRAPHY[:normal_weight]
            style[:stereotype_font_style] = EA_TYPOGRAPHY[:normal_style]
          end

          # Attribute text styling
          if element[:attributes]
            style[:attribute_font_family] = EA_TYPOGRAPHY[:primary_font]
            style[:attribute_font_size] = EA_TYPOGRAPHY[:attribute_size]
            style[:attribute_font_weight] = EA_TYPOGRAPHY[:normal_weight]
            style[:attribute_font_style] = EA_TYPOGRAPHY[:normal_style]
          end

          # Text stroke styling (EA uses this for text elements)
          style[:text_stroke] = EA_COLORS[:border_normal]
          style[:text_stroke_opacity] = "0.00"
          style[:text_stroke_width] = "0"

          style
        end

        # Parse EA style string into style properties (EA uses specific format)
        # @param style_string [String] EA style string
        # @return [Hash] Parsed style properties
        def parse_ea_style_string(style_string) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          return {} unless style_string

          style = {}

          # Split by semicolons and parse each property (EA format)
          style_string.split(";").each do |property|
            key, value = property.split("=", 2)
            next unless key && value

            case key.downcase
            when "backcolor", "fillcolor"
              # EA stores colors as integers, convert to hex
              style[:fill] = color_from_ea_color(value.to_i)
            when "linecolor", "bordercolor"
              style[:stroke] = color_from_ea_color(value.to_i)
            when "font"
              style[:font_family] = value
            when "fontsize"
              style[:font_size] = "#{value}pt"
            when "bold"
              style[:font_weight] = if value == "1"
                                      EA_TYPOGRAPHY[:bold_weight]
                                    else
                                      EA_TYPOGRAPHY[:normal_weight]
                                    end
            when "italic"
              style[:font_style] = if value == "1"
                                     EA_TYPOGRAPHY[:italic_style]
                                   else
                                     EA_TYPOGRAPHY[:normal_style]
                                   end
            end
          end

          style
        end

        # Convert EA color integer to hex color
        # (EA stores colors as BGR integers)
        # @param ea_color [Integer] EA color value
        # @return [String] Hex color string
        def color_from_ea_color(ea_color)
          return EA_COLORS[:class_fill] if ea_color.zero?

          # EA colors are stored as BGR, convert to RGB
          b = (ea_color & 0xFF0000) >> 16
          g = (ea_color & 0x00FF00) >> 8
          r = ea_color & 0x0000FF

          format("#%02x%02x%02x", r, g, b).upcase # rubocop:disable Style/FormatStringToken
        end

        # Get stereotype-specific styling
        # (EA has specific colors for stereotypes)
        # @param stereotype [String] Stereotype name
        # @return [Hash] Style overrides
        def stereotype_style(stereotype) # rubocop:disable Metrics/MethodLength
          case stereotype.to_s.downcase
          when "featuretype", "enumeration", "interface"
            # Light yellow for FeatureType, Enumeration, Interface
            { fill: "#FFFFCC" }
          when "datatype"
            { fill: "#FFCCFF" }  # Light pink for DataType
          when "type"
            { fill: "#CCFFCC" }  # Light green for Type
          else
            {}
          end
        end
      end
    end
  end
end
