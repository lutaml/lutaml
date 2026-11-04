# frozen_string_literal: true

module Lutaml
  module Jsonschema
    module Exports
      # Renders a SchemaSet as CDDL (RFC 8610) text.
      #
      # Approximation notes: JSON Schema is open by default, CDDL maps are
      # closed — an explicit `* text => any` (or the additionalProperties
      # schema) is emitted when the source declares one, and omitted when
      # additionalProperties is absent or false. `allOf` has no CDDL
      # intersection equivalent; its members are not merged. Boolean
      # schemas render as `any` (CDDL has no uninhabited type for `false`).
      class Cddl
        TYPE_NAMES = {
          "string" => "text",
          "integer" => "int",
          "number" => "float",
          "boolean" => "bool",
          "null" => "null",
        }.freeze
        KEY_PATTERN = /\A[A-Za-z_][A-Za-z0-9_]*\z/

        def initialize(schema_set)
          @schema_set = schema_set
        end

        # Renders every schema in the set: definitions become named
        # groups, and each root schema becomes a named type of its
        # document name.
        def render
          sections = []
          @schema_set.schemas.each do |name, schema|
            schema.definition_entries.each do |entry|
              sections << "#{entry.name} = #{type_for(entry.schema_value, entry.name)}"
            end
            sections << "#{name} = #{type_for(schema, name)}"
          end
          "#{sections.join("\n\n")}\n"
        end

        private

        def type_for(schema, context_name)
          return "any" unless schema.is_a?(Schema)

          keyword_type(schema) || shape_type(schema, context_name)
        end

        # Keywords that name a type outright, in precedence order; nil
        # when the schema is shaped by type/properties/items instead.
        def keyword_type(schema)
          return ref_name(schema.dollar_ref) || "any" if schema.dollar_ref
          return literal(schema.const) if schema.const

          enum_or_composite(schema)
        end

        def enum_or_composite(schema)
          return enum_type(schema) if schema.enum&.any?
          return composite_type(schema) if schema.types.length > 1

          nil
        end

        def enum_type(schema)
          schema.enum.map { |value| literal(value) }.join(" / ")
        end

        def composite_type(schema)
          schema.types.map { |type| scalar_type(schema, type) }.join(" / ")
        end

        def shape_type(schema, context_name)
          return map_type(schema, context_name) if object_type?(schema)
          return array_type(schema) if array_type?(schema)

          scalar_type(schema)
        end

        def object_type?(schema)
          schema.types.include?("object") || schema.property_entries.any?
        end

        def array_type?(schema)
          schema.types.include?("array") || schema.prefix_items.any?
        end

        def scalar_type(schema, type = nil)
          TYPE_NAMES[type || schema.types.first] || "any"
        end

        def map_type(schema, _context_name)
          members = schema.property_entries.map { |entry| member(entry, schema) }
          members.concat(additional_members(schema))
          members.empty? ? "{}" : "{ #{members.join(', ')} }"
        end

        def member(entry, schema)
          marker = schema.required.include?(entry.name) ? nil : "?"
          "#{marker}#{map_key(entry.name)}: #{type_for(entry.schema_value, entry.name)}"
        end

        def additional_members(schema)
          if schema.additional_properties_schema
            ["* text => #{type_for(schema.additional_properties_schema,
                                   'additional')}"]
          elsif schema.additional_properties == true
            ["* text => any"]
          else
            []
          end
        end

        def array_type(schema)
          tuple = schema.tuple_items
          return tuple_type(schema, tuple) if tuple

          return "[]" if schema.items_boolean == false
          return "[* any]" if schema.items.nil?

          "[* #{type_for(schema.items, 'item')}]"
        end

        def tuple_type(schema, tuple)
          members, unreachable = tuple_member_list(tuple)
          unless unreachable || schema.items_closed?
            members << tail_member(schema)
          end
          "[#{members.join(', ')}]"
        end

        # A `false` entry makes the position unreachable, so the tuple ends
        # there (and no rest member is allowed).
        def tuple_member_list(tuple)
          members = []
          tuple.each do |item|
            break if item == false

            members << (item == true ? "any" : type_for(item, "item"))
          end
          [members, tuple.include?(false)]
        end

        def tail_member(schema)
          tail = schema.additional_items_schema
          tail = schema.items if tail.nil? && schema.items.is_a?(Schema)
          tail ? "* #{type_for(tail, 'item')}" : "* any"
        end

        def ref_name(ref)
          return nil unless ref.start_with?("#/")

          ref.delete_prefix("#/").split("/").last
        end

        # CDDL literals: JSON strings, numbers, booleans, null.
        def literal(value)
          case value
          when String then value.inspect
          when nil then "null"
          else value.to_s
          end
        end

        def map_key(name)
          name.match?(KEY_PATTERN) ? name : name.inspect
        end
      end
    end
  end
end
