# frozen_string_literal: true

require_relative "defs_builder"

module Lutaml
  module Xsd
    module Spa
      module Svg
        # Assembles final SVG document from components
        class DocumentBuilder
          attr_reader :config

          def initialize(config)
            @config = config
            @defs_builder = DefsBuilder.new(config)
          end

          def build(components, dimensions)
            width = dimensions&.width || 800
            height = dimensions&.height || 600
            <<~SVG
              <svg xmlns="http://www.w3.org/2000/svg"
                   xmlns:xlink="http://www.w3.org/1999/xlink"
                   width="#{width}" height="#{height}"
                   viewBox="0 0 #{width} #{height}">
                #{@defs_builder.build}
                #{build_styles}
                <g id="diagram-content">
                  #{components.join("\n")}
                </g>
              </svg>
            SVG
          end

          private

          def build_styles
            <<~STYLES
              <style>
                <![CDATA[
                .element-box:hover rect { opacity: 0.9; cursor: pointer; }
                .type-box:hover rect { opacity: 0.9; cursor: pointer; }
                .attribute-box:hover rect { opacity: 0.9; cursor: pointer; }
                .child-element:hover rect { opacity: 0.9; cursor: pointer; }
                .group-box:hover rect { opacity: 0.9; }
                a { cursor: pointer; }
                text { user-select: none; }
                ]]>
              </style>
            STYLES
          end
        end
      end
    end
  end
end
