# frozen_string_literal: true

module Lutaml
  module Xsd
    module Spa
      module Svg
        module Config
          # Value object for connector styling configuration
          class ConnectorStyles
            def initialize(connectors_hash)
              @connectors = connectors_hash
            end

            def inheritance
              ConnectorStyle.new(@connectors["inheritance"] || {})
            end

            def containment
              ConnectorStyle.new(@connectors["containment"] || {})
            end

            def reference
              ConnectorStyle.new(@connectors["reference"] || {})
            end

            def for_type(connector_type)
              case connector_type.to_s
              when "inheritance"
                inheritance
              when "containment"
                containment
              when "reference"
                reference
              else
                inheritance # default
              end
            end
          end

          # Individual connector style value object
          class ConnectorStyle
            attr_reader :type, :stroke_width, :arrow_size, :dash_pattern

            def initialize(style_hash)
              @type = style_hash["type"] || "hollow_triangle"
              @stroke_width = style_hash["stroke_width"] || 2
              @arrow_size = style_hash["arrow_size"] || 8
              @dash_pattern = style_hash["dash_pattern"]
            end

            def dashed?
              !@dash_pattern.nil?
            end
          end
        end
      end
    end
  end
end
