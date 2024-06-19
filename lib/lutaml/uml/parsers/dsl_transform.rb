# frozen_string_literal: true

require "parslet"

module Lutaml
  module Uml
    module Parsers
      # Class for additional transformations of LutaML syntax:
      # visibility modifier etc
      class DslTransform < Parslet::Transform
        rule(visibility_modifier: simple(:visibility_value)) do
          case visibility_value
          when "-"
            "private"
          when "#"
            "protected"
          when "~"
            "friendly"
          else
            "public"
          end
        end
        rule(simple(:member)) { member.nil? ? member : member.to_s.strip }
      end
    end
  end
end
