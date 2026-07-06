# frozen_string_literal: true

require "parslet"

module Lutaml
  module Uml
    module Parsers
      # Class for additional transformations of LutaML syntax:
      # visibility modifier etc
      class DslTransform < Parslet::Transform
        # Maps one-line association operator adornments to end-type values.
        # Left adornment -> owner_end_type, right adornment -> member_end_type.
        OWNER_OP_TYPE = {
          "*" => "composition", "o" => "aggregation",
          "<|" => "inheritance", "<" => "direct"
        }.freeze
        MEMBER_OP_TYPE = {
          "*" => "composition", "o" => "aggregation",
          "|>" => "inheritance", ">" => "direct"
        }.freeze

        # Desugar a one-line association shorthand subtree into the same
        # `{ associations: { ... } }` hash the verbose `association { }` block
        # produces, so the converter (DslToUml) needs no changes.
        rule(assoc_shortcut: subtree(:parts)) do
          src = parts.is_a?(Hash) ? parts : {}
          assoc = {}
          %w[owner_end member_end
             owner_end_attribute_name member_end_attribute_name
             owner_end_cardinality member_end_cardinality].each do |key|
            assoc[key] = src[key] if src[key]
          end
          if (left = src[:op_left])
            assoc["owner_end_type"] = OWNER_OP_TYPE[left.to_s]
          end
          if (right = src[:op_right])
            assoc["member_end_type"] = MEMBER_OP_TYPE[right.to_s]
          end
          { associations: assoc }
        end

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
