# frozen_string_literal: true

module Lutaml
  module Jsonschema
    module Exports
      # Renders a SchemaSet as LutaML Model Language (LML) — the org's
      # authoring DSL for UML models (lutaml-lml), from which the `lutaml`
      # CLI renders diagrams and metanorma-plugin-lutaml embeds models.
      #
      # Mapping: definitions that are objects become `class` blocks (a
      # property $ref'd to another top-level definition is a UML
      # association; arrays of it carry 0..n/1..n cardinality), enum
      # definitions become `enum` blocks, and enum-valued properties
      # become inline `values` sets. Required members get `cardinality 1`,
      # optional or nullable ones `0..1` (arrays `1..n`/`0..n`).
      #
      # Approximation notes: inline (unreferenced) nested objects map to
      # Hash; $refs into nested definitions resolve to the target's
      # scalar/enum type (only top-level definition targets become
      # associations); tuple/prefixItems shapes collapse to an untyped
      # attribute with the structure in the description; unions
      # (oneOf/anyOf) become their variant summary in the description;
      # enum member names are sanitized to LML identifiers, the original
      # value kept in the member description when changed.
      class Lml
        PRIMITIVES = {
          "string" => "String",
          "integer" => "Integer",
          "number" => "Float",
          "boolean" => "Boolean",
          "null" => nil,
        }.freeze

        FORMATS = {
          "date" => "Date",
          "date-time" => "DateTime",
          "time" => "Time",
          "uri" => "Uri",
          "iri" => "Uri",
          "uri-reference" => "Uri",
          "iri-reference" => "Uri",
        }.freeze

        def initialize(schema_set)
          @schema_set = schema_set
        end

        def render
          blocks = []
          seen = {}
          @schema_set.schemas.each do |name, schema|
            collect_definitions(schema, schema, seen, blocks)
            blocks << "// schema #{name}: only the definitions render as " \
                      "LML classes and enums"
          end
          "#{blocks.join("\n\n")}\n"
        end

        private

        # `root` is the document root: #/-pointer refs resolve against it.
        def collect_definitions(root, schema, seen, blocks)
          schema.definition_entries.each do |entry|
            block = render_definition(entry, root)
            next if block.nil? || seen.key?(entry.name) # dup names across files

            seen[entry.name] = true
            blocks << block
          end
        end

        def render_definition(entry, root)
          value = entry.schema_value
          return nil unless value.is_a?(Schema)
          return enum_block(entry.name, value.enum) if enum_definition?(value)

          class_block(entry.name, value, root)
        end

        def enum_definition?(schema)
          schema.enum && schema.property_entries.empty?
        end

        def enum_block(name, values)
          members = values.map { |v| "  #{sanitize_identifier(v)}" }
          "enum #{sanitize_identifier(name)} {\n#{members.join("\n")}\n}"
        end

        def class_block(name, schema, root)
          body = schema.property_entries.map { |prop| attribute_block(prop, schema, root) }
          "class #{sanitize_identifier(name)} {\n#{body.join("\n")}\n}"
        end

        def attribute_block(prop, owner, root)
          value = prop.schema_value
          return "  // #{prop.name}: no value allowed" if value == false
          return "  #{sanitize_identifier(prop.name)}" if value == true

          body = attribute_body(prop, value, owner, root)
          "  attribute #{sanitize_identifier(prop.name)} {\n#{body}\n  }"
        end

        def attribute_body(prop, value, owner, root)
          lines = ["    #{cardinality(prop.name, value, owner.required)}"]
          lines.unshift("    type #{lml_type(value, root)}") if lml_type(value, root)
          lines << "    #{values_line(value)}" if value.enum
          lines << "    #{description_line(value)}" if present?(value.description)
          lines.join("\n")
        end

        def description_line(value)
          "description #{lml_string(plain(value.description))}"
        end

        def cardinality(name, value, required)
          needed = required.include?(name) && !nullable?(value)
          return array_cardinality(value, needed) if array?(value)

          needed ? "cardinality 1" : "cardinality 0..1"
        end

        def array_cardinality(value, needed)
          dense = needed && (value.min_items || 0).positive?
          dense ? "cardinality 1..n" : "cardinality 0..n"
        end

        def values_line(schema)
          members = schema.enum.map { |v| sanitize_identifier(v) }
          "values { #{members.join(', ')} }"
        end

        def lml_type(value, owner)
          return resolved_ref_type(value.dollar_ref, owner) if value.dollar_ref
          return array_item_type(value, owner) if array?(value)

          primitive_type(value)
        end

        def array_item_type(schema, root)
          item = schema.items
          return resolved_ref_type(item.dollar_ref, root) if item&.dollar_ref

          item ? primitive_type(item) : nil
        end

        # A $ref to a top-level definition names a class (association);
        # any other ref resolves to its target and types by that.
        def resolved_ref_type(ref, root)
          name = ref.to_s.split("/").last
          association = name && known_definition_names.include?(name) &&
            ref.to_s.end_with?("definitions/#{name}")
          return name if association

          target = @schema_set.resolve_ref(ref, root)
          return lml_type(target, root) if target.is_a?(Schema)

          nil
        end

        def primitive_type(schema)
          kinds = schema.types - ["null"]
          return "Hash" if kinds.include?("object")
          return nil if kinds.empty? || kinds.include?("array")

          formatted = FORMATS[schema.format]
          return formatted if formatted && kinds == ["string"]

          PRIMITIVES[kinds.first]
        end

        def nullable?(value)
          value.is_a?(Schema) && value.types.include?("null")
        end

        def array?(value)
          value.is_a?(Schema) && (value.types.include?("array") ||
                                  (value.items && !value.types.include?("object")))
        end

        def known_definition_names
          @known_definition_names ||=
            @schema_set.schemas.values.flat_map(&:definition_entries).map(&:name)
        end

        def sanitize_identifier(value)
          text = value.to_s
          id = text.gsub(/[^A-Za-z0-9_]/, "_")
          id = "_#{id}" if id.empty? || id.start_with?(/\d/)
          id
        end

        def lml_string(text)
          "\"#{text.gsub('\\', '\\\\\\\\').gsub('"', '\"')}\""
        end

        def plain(text)
          text.to_s.gsub(/\s+/, " ").strip
        end

        def present?(value)
          value && !value.to_s.empty?
        end
      end
    end
  end
end
