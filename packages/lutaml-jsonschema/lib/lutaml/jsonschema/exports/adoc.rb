# frozen_string_literal: true

module Lutaml
  module Jsonschema
    module Exports
      # Renders a SchemaSet as an AsciiDoc reference document, suitable for
      # Metanorma/standards-body pipelines.
      #
      # Approximation notes: descriptions and constraints are prose; boolean
      # schemas render as "any value" / "no value"; external HTTP(S) $refs
      # retain their schema URI as a link.
      #
      # With embeddable: true the document title (the level-0 `=` heading)
      # is dropped and definition anchors are prefixed with the schema
      # name, so the output can be `include::`-ed into a Metanorma
      # document — or any AsciiDoc host — without heading-level or
      # anchor collisions.
      class Adoc
        def initialize(schema_set, embeddable: false)
          @schema_set = schema_set
          @embeddable = embeddable
        end

        def render
          @linked_schemas = {}
          parts = rendered_sections.map do |name, section|
            @linked_schemas[name] ? "[##{schema_anchor_id(name)}]\n#{section}" : section
          end
          parts.unshift(document_title) unless @embeddable
          "#{parts.join("\n\n").strip}\n"
        end

        private

        def rendered_sections
          sections = {}
          until (pending = @schema_set.schemas.keys - sections.keys).empty?
            pending.each do |name|
              sections[name] = render_schema(name, @schema_set.schemas.fetch(name))
            end
          end
          sections
        end

        def document_title
          title = @schema_set.schemas.values.first&.title
          "= #{title || 'JSON Schema Reference'}"
        end

        def render_schema(name, schema)
          @current_name = name
          @current_schema = schema
          lines = ["== #{schema.title || name}", ""] + body_lines(schema)
          schema.definition_entries.each do |entry|
            lines << render_definition(entry) << ""
          end
          lines.join("\n").strip
        end

        def body_lines(schema)
          lines = []
          lines << "#{schema.description}\n" if present?(schema.description)
          if schema.property_entries.empty?
            lines << "Type: #{type_label(schema)}" << ""
          else
            lines.concat(properties_table(schema))
          end
          lines
        end

        def render_definition(entry)
          value = entry.schema_value
          body = if value.is_a?(Schema)
                   body_lines(value)
                 else
                   [value ? "Any value." : "No value allowed.", ""]
                 end
          lines = ["[##{anchor_id(entry.name)}]", "=== #{entry.name}",
                   ""] + body
          lines.join("\n").strip
        end

        def properties_table(schema)
          return [] if schema.property_entries.empty?

          required = schema.required || []
          lines = ['[cols="2,2,1,4",options="header"]', "|==="]
          lines << "|Name |Type |Required |Description"
          schema.property_entries.each do |entry|
            lines << property_row(entry, required)
          end
          lines << "|===" << ""
          lines
        end

        def property_row(entry, required)
          cells = [
            "`#{entry.name}`",
            type_label(entry.schema_value),
            required.include?(entry.name) ? "Yes" : "No",
            description_cell(entry.schema_value),
          ]
          "|#{cells.map { |cell| escape_cell(cell) }.join(' |')}"
        end

        def type_label(value)
          return "any value" if value == true
          return "no value" if value == false
          return "any" unless value.is_a?(Schema)

          schema_type_label(value)
        end

        def schema_type_label(schema)
          return ref_link(schema.dollar_ref) if schema.dollar_ref

          tuple = schema.tuple_items
          return tuple_label(schema, tuple) if tuple
          return "array of #{type_label(schema.items)}" if array?(schema)

          schema.type || schema.title || "any"
        end

        def tuple_label(schema, tuple)
          members = tuple.map { |item| type_label(item) }
          unless schema.items_closed?
            tail = schema.items_tail_schema
            members << (tail ? type_label(tail) : "...")
          end
          "[#{members.join(', ')}]"
        end

        def array?(schema)
          schema.types.include?("array") || schema.items || schema.prefix_items.any?
        end

        def description_cell(value)
          return "" unless value.is_a?(Schema)

          parts = []
          if present?(value.description)
            parts << value.description.to_s.strip.delete_suffix(".")
          end
          summary = constraints(value)
          parts << summary if summary
          parts.join("; ")
        end

        def constraints(schema)
          items = []
          items << "Allowed: #{schema.enum.join(', ')}" if schema.enum&.any?
          items << "Pattern: `#{schema.pattern}`" if present?(schema.pattern)
          items.concat(range_constraints(schema))
          items.empty? ? nil : items.join("; ")
        end

        def range_constraints(schema)
          [
            bounded("Minimum", schema.minimum),
            bounded("Maximum", schema.maximum),
            bounded("Min length", schema.min_length),
            bounded("Max length", schema.max_length),
          ].compact
        end

        def bounded(label, value)
          "#{label}: #{number(value)}" unless value.nil?
        end

        def number(value)
          value == value.to_i ? value.to_i.to_s : value.to_s
        end

        def ref_link(ref)
          if ref.start_with?("http://", "https://")
            return "link:#{ref}[#{ref.split(%r{[/#]}).last}]"
          end

          target = @schema_set.resolve_ref(ref, @current_schema)
          resolved = resolved_ref_link(target) if target.is_a?(Schema)
          return resolved if resolved

          name = local_reference_name(ref)
          "<<#{anchor_id(name)},#{name}>>"
        end

        def local_reference_name(ref)
          if ref.start_with?("#") && !ref.start_with?("#/")
            named_anchor_definition(ref.delete_prefix("#"))
          else
            ref.split("/").last.to_s.gsub("~1", "/").gsub("~0", "~")
          end
        end

        def resolved_ref_link(target)
          @schema_set.schemas.each do |name, schema|
            if schema.equal?(target)
              @linked_schemas[name] = true
              return "<<#{schema_anchor_id(name)},#{schema.title || name}>>"
            end
            entry = schema.definition_entries.find do |definition|
              definition.schema_value.equal?(target)
            end
            return "<<#{anchor_id(entry.name, name)},#{entry.name}>>" if entry
          end
          nil
        end

        def schema_anchor_id(name)
          "schema-#{anchor_slug(name)}"
        end

        def named_anchor_definition(anchor)
          entry = @current_schema.definition_entries.find do |definition|
            value = definition.schema_value
            value.is_a?(Schema) && value.dollar_anchor == anchor
          end
          entry ? entry.name : anchor
        end

        # definition anchors: `def-<name>` standalone, `def-<schema>-<name>`
        # when embedded so a host document (and sibling includes) cannot
        # collide
        def anchor_slug(name)
          name.to_s.gsub(/[^A-Za-z0-9_-]/, "-").downcase
        end

        def anchor_id(name, schema_name = @current_name)
          prefix = @embeddable ? "#{anchor_slug(schema_name)}-" : ""
          id = name.to_s.gsub(/[^A-Za-z0-9_-]/, "-")
          "def-#{prefix}#{id}"
        end

        def escape_cell(text)
          text.to_s.gsub("|", "\\\\|").gsub("\n", " ").strip
        end

        def present?(value)
          !value.nil? && !value.to_s.empty?
        end
      end
    end
  end
end
