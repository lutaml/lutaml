# frozen_string_literal: true

require_relative "configuration"
require_relative "style_parser"

module Lutaml
  module Ea
    module Diagram
      # Resolves styles for diagram elements by merging multiple sources
      #
      # Priority order (highest to lowest):
      # 1. EA Data from DiagramObject.style (BCol, LCol, etc.)
      # 2. User Configuration (YAML)
      # 3. Built-in Defaults
      #
      # This ensures that:
      # - EA's original styling is preserved when present
      # - Users can override defaults via configuration
      # - Sensible defaults are always available
      class StyleResolver
        attr_reader :configuration, :style_parser

        # Initialize with configuration
        #
        # @param config_path [String, nil] Path to configuration file
        def initialize(config_path = nil)
          @configuration = Configuration.new(config_path)
          @style_parser = StyleParser.new
        end

        # Resolve complete style for an element
        #
        # @param element [Object] UML element (Class, DataType, etc.)
        # @param diagram_object [Lutaml::Uml::DiagramObject, nil]
        # Diagram placement data
        # @return [Hash] Complete resolved style
        def resolve_element_style(element, diagram_object = nil) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          style = {}

          # Start with configuration defaults
          style[:fill] = configuration.style_for(element, "colors.fill")
          style[:stroke] = configuration.style_for(element, "colors.stroke")
          style[:stroke_width] =
            configuration.style_for(element, "box.stroke_width")
          style[:stroke_linecap] =
            configuration.style_for(element, "box.stroke_linecap")
          style[:stroke_linejoin] =
            configuration.style_for(element, "box.stroke_linejoin")
          style[:corner_radius] =
            configuration.style_for(element, "box.corner_radius")
          style[:fill_opacity] =
            configuration.style_for(element, "box.fill_opacity")
          style[:stroke_opacity] =
            configuration.style_for(element, "box.stroke_opacity")

          # Font configuration
          style[:font_family] =
            configuration.style_for(element, "fonts.class_name.family")
          style[:font_size] =
            configuration.style_for(element, "fonts.class_name.size")
          style[:font_weight] =
            configuration.style_for(element, "fonts.class_name.weight")
          style[:font_style] =
            configuration.style_for(element, "fonts.class_name.style")

          # Override with EA data if present (highest priority)
          if diagram_object&.style
            ea_style = parse_diagram_object_style(diagram_object.style)
            style.merge!(ea_style)
          end

          style.compact
        end

        # Resolve complete style for a connector
        #
        # @param connector [Object] UML connector
        # (Association, Generalization, etc.)
        # @param diagram_link [Lutaml::Uml::DiagramLink, nil]
        # Diagram routing data
        # @return [Hash] Complete resolved style
        def resolve_connector_style(connector, diagram_link = nil) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          # Determine connector type
          connector_type = determine_connector_type(connector)

          style = {}

          # Start with configuration defaults for this connector type
          style[:arrow_type] =
            configuration.connector_style(connector_type, "arrow.type")
          style[:arrow_size] =
            configuration.connector_style(connector_type, "arrow.size")
          style[:stroke] =
            configuration.connector_style(connector_type, "line.stroke")
          style[:stroke_width] =
            configuration.connector_style(connector_type, "line.stroke_width")
          style[:stroke_dasharray] =
            configuration.connector_style(connector_type,
                                          "line.stroke_dasharray")
          style[:fill] =
            configuration.connector_style(connector_type, "line.fill") || "none"

          # Override with EA data if present (highest priority)
          if diagram_link&.style
            ea_style = parse_diagram_link_style(diagram_link.style)
            style.merge!(ea_style)
          end

          style.compact
        end

        # Resolve fill color specifically
        #
        # @param element [Object] UML element
        # @param diagram_object [Lutaml::Uml::DiagramObject, nil]
        # Diagram placement data
        # @return [String] Resolved fill color
        def resolve_fill_color(element, diagram_object = nil)
          # Priority 1: EA data from DiagramObject.style
          if diagram_object&.style
            ea_style = parse_diagram_object_style(diagram_object.style)
            return ea_style[:fill] if ea_style[:fill]
          end

          # Priority 2: Configuration (Class > Package > Stereotype > Defaults)
          configuration.style_for(element, "colors.fill")
        end

        # Resolve stroke color specifically
        #
        # @param element [Object] UML element
        # @param diagram_object [Lutaml::Uml::DiagramObject, nil]
        # Diagram placement data
        # @return [String] Resolved stroke color
        def resolve_stroke_color(element, diagram_object = nil)
          # Priority 1: EA data from DiagramObject.style
          if diagram_object&.style
            ea_style = parse_diagram_object_style(diagram_object.style)
            return ea_style[:stroke] if ea_style[:stroke]
          end

          # Priority 2: Configuration
          configuration.style_for(element, "colors.stroke")
        end

        # Resolve font properties
        #
        # @param element [Object] UML element
        # @param context [Symbol] Font context
        # (:class_name, :attribute, :operation, :stereotype)
        # @return [Hash] Font properties (family, size, weight, style)
        def resolve_font(element, context = :class_name)
          {
            family: configuration.style_for(element, "fonts.#{context}.family"),
            size: configuration.style_for(element, "fonts.#{context}.size"),
            weight: configuration.style_for(element, "fonts.#{context}.weight"),
            style: configuration.style_for(element, "fonts.#{context}.style"),
          }.compact
        end

        # Backward compatibility alias
        # @deprecated Use resolve_element_style instead
        alias parse_element_style resolve_element_style

        private

        # Parse DiagramObject.style string
        # (EA format: "BCol=16764159;LCol=0;SOID=123")
        #
        # @param style_string [String] EA style string
        # @return [Hash] Parsed style with fill and stroke colors
        def parse_diagram_object_style(style_string) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          return {} unless style_string

          style = {}
          pairs = style_string.split(";")

          pairs.each do |pair|
            key, value = pair.split("=", 2)
            next unless key && value

            case key.strip
            when "BCol"
              # Background color (BGR integer)
              style[:fill] = style_parser.send(:color_from_ea_color, value.to_i)
            when "LCol"
              # Line color (BGR integer)
              style[:stroke] =
                style_parser.send(:color_from_ea_color, value.to_i)
            when "BFol"
              # Bold font (0 or 1)
              style[:font_weight] = value == "1" ? 700 : 400
            when "IFol"
              # Italic font (0 or 1)
              style[:font_style] = value == "1" ? "italic" : "normal"
            when "LWth"
              # Line width
              style[:stroke_width] = value.to_i
            end
          end

          style
        end

        # Parse DiagramLink.style string
        #
        # @param style_string [String] EA style string
        # @return [Hash] Parsed style
        def parse_diagram_link_style(style_string) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength
          return {} unless style_string

          style = {}
          pairs = style_string.split(";")

          pairs.each do |pair|
            key, value = pair.split("=", 2)
            next unless key && value

            case key.strip
            when "LCol"
              # Line color
              style[:stroke] =
                style_parser.send(:color_from_ea_color, value.to_i)
            when "LWth"
              # Line width
              style[:stroke_width] = value.to_i
            when "LStyle"
              # Line style (0=solid, 1=dash, 2=dot, etc.)
              case value.to_i
              when 1
                style[:stroke_dasharray] = "5,5"
              when 2
                style[:stroke_dasharray] = "2,2"
              end
            end
          end

          style
        end

        # Determine connector type from connector object
        #
        # @param connector [Object] UML connector
        # @return [String] Connector type name
        def determine_connector_type(connector) # rubocop:disable Metrics/MethodLength
          return "association" unless connector

          case connector.class.name
          when /Generalization/
            "generalization"
          when /Association/
            determine_association_type(connector)
          when /Dependency/
            "dependency"
          when /Realization/
            "realization"
          else
            "association"
          end
        end

        # Determine specific association type
        #
        # @param connector [Object] Association connector
        # @return [String] Specific association type
        def determine_association_type(connector) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/MethodLength
          return "association" unless connector.respond_to?(:member_end)
          return "association" unless connector.member_end

          # Ensure member_end is an array (handle legacy data
          # where it might be a string)
          member_ends = Array(connector.member_end)

          # Check for aggregation or composition
          member_ends.each do |end_point|
            if end_point.respond_to?(:aggregation)
              case end_point.aggregation&.downcase
              when "shared"
                return "aggregation"
              when "composite"
                return "composition"
              end
            end
          end

          "association"
        end
      end
    end
  end
end
