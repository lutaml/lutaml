# frozen_string_literal: true

require_relative "utils/extract_enumeration"

module Lutaml
  module Xsd
    module Spa
      # Generates XML instance representations showing how to use XSD components
      # Based on xs3p's SampleInstanceTable templates
      class XmlInstanceGenerator
        include ::Lutaml::Xsd::Spa::Utils::ExtractEnumeration

        attr_reader :schema, :component, :repository

        def initialize(schema, component, repository = nil, all_schemas: nil)
          @schema = schema
          @component = component
          @repository = repository
          @all_schemas = all_schemas || {}
          @visited_types = []
        end

        # Generate instance representation
        def generate
          case @component
          when Element
            generate_element_instance(@component)
          when ComplexType
            generate_type_instance(@component)
          when SimpleType
            generate_simple_type_instance(@component)
          when AttributeGroup
            generate_ag_instance(@component)
          else
            "<!-- Unknown component type -->"
          end
        end

        private

        # Generate element instance with attributes and content
        def generate_element_instance(element, indent: 1)
          element_type = find_type(element.type)
          generate_type_instance(
            element_type, tag_name: element.name, indent: indent
          )
        end

        # Generate type instance content
        def generate_type_instance(type, tag_name: "...", indent: 1)
          lines = []
          indent_str = "  " * indent

          # Collect attributes
          attr_parts = generate_attributes_instance(type.name)

          # Collect element
          element_parts = []

          if type.sequence
            # check whether the type is mixed
            if type.mixed
              element_parts << "#{indent_str}<!-- Mixed content -->"
            end

            # generate start sequence line with occurrence
            # if maxOccurs is unbounded
            if type.sequence&.max_occurs == "unbounded"
              occurs = element_occurs(type.sequence)
              element_parts << "#{indent_str}Start Sequence #{occurs}"
            end

            # Check whether the sequence allows any element
            if type.sequence&.any && !type.sequence&.any&.empty?
              occurs = element_occurs(type.sequence.any.first)
              element_parts << "#{indent_str * 2}" \
                               "Allow any elements from any namespace " \
                               "(skip validation). " \
                               "#{occurs}"
            end

            # generate element lines
            if type.sequence&.element&.any?
              elements = type.sequence.element
              elements.each do |element|
                element_parts << generate_element_parts(element, indent_str)
              end
            end

            # generate end sequence line
            if type.sequence&.max_occurs == "unbounded"
              element_parts << "#{indent_str}End Sequence"
            end
          end

          # Build opening tag
          if attr_parts.any?
            # with attributes
            lines << "<#{tag_name}"
            attr_parts.each do |attr_part|
              lines << "#{indent_str}#{attr_part}"
            end
            lines << ">"
          else
            # without attributes
            lines << "<#{tag_name}>"
          end

          # Build content
          base_val = get_base_from_extension(type)
          if base_val
            lines << "#{indent_str}#{base_val}"
          end

          # Build element lines
          element_parts.each do |element_line|
            lines << element_line
          end

          # Build closing tag
          lines << "</#{tag_name}>"

          lines.join("\n")
        end

        # Generate attribute group instance
        def generate_ag_instance(attr_group)
          # Collect attributes
          attrs = generate_attributes_from_attribute_group(attr_group)
          attr_parts = generate_attributes_parts(attrs)
          attr_parts.join("\n")
        end

        # Generate element instance for a type
        def generate_element_parts(element, indent_str)
          tag_name = element.name || element.ref
          "#{indent_str * 2}" \
            "<#{tag_name}> ... </#{tag_name}> #{element_occurs(element)}"
        end

        # Generate attributes xml instance for a type
        def generate_attributes_instance(type_name)
          type = find_type(type_name)
          return [] unless type

          attrs = collect_attributes(type)
          generate_attributes_parts(attrs)
        end

        # Generate attributes parts from attributes
        def generate_attributes_parts(attrs)
          attr_parts = []
          attrs.each do |attr|
            attr_name = resolve_attribute_name(attr)
            next unless attr_name

            enum_default, enum_type = extract_enumeration_default(attr)
            occurs = attribute_occurs(attr)
            default_val = enum_default || attr.fixed || attr.default
            attr_type = enum_type || attr.type || "string"
            type_link = get_type_link_marker(attr_type)

            attr_parts << if default_val
                            "#{attr_name}=\"#{attr_type} (#{default_val})\" " \
                              "#{occurs}"
                          else
                            "#{attr_name}=\"#{attr_type}#{type_link}\" " \
                              "#{occurs}"
                          end
          end

          attr_parts
        end

        # Generate simple type instance
        def generate_simple_type_instance(simple_type, _indent: 1)
          extract_simple_constraints(simple_type)
        end

        # Extract simple type constraints
        def extract_simple_constraints(simple_content)
          return "string" unless simple_content

          if simple_content.restriction
            restriction = simple_content.restriction
            base = restriction.base || "string"

            # Check for enumerations
            if restriction.enumeration&.any?
              enums = restriction.enumeration.map(&:value).join(" | ")
              return "(#{enums})"
            end

            # Check for patterns
            if restriction.pattern&.any?
              pattern = restriction.pattern.first
              return "pattern: #{pattern.value}" if pattern.value
            end

            # Check for length constraints
            constraints = []
            constraints << "minLength: #{restriction.min_length.first.value}" if restriction.min_length&.any?
            constraints << "maxLength: #{restriction.max_length.first.value}" if restriction.max_length&.any?

            return "#{base} (#{constraints.join(', ')})" if constraints.any?

            base
          elsif simple_content.extension
            simple_content.extension.base || "string"
          else
            "string"
          end
        end

        # Calculate element occurrence notation
        def element_occurs(element)
          min = element.min_occurs || "1"
          max = element.max_occurs == "unbounded" ? "*" : (element.max_occurs || "1")
          "[#{min}..#{max}]"
        end

        # Calculate attribute occurrence notation
        def attribute_occurs(attr)
          use = attr.use || "optional"
          use == "required" ? "[1]" : "[0..1]"
        end

        # Calculate model group occurrence notation
        def model_group_occurs(group)
          return "[1]" unless group

          element_occurs(group)
        end

        # Check if type has complex_content
        def has_complex_content?(type)
          type.complex_content
        end

        # Resolve element name from element (handles ref attribute)
        def resolve_element_name(elem)
          return elem.name if elem.name

          # Element uses ref - extract the local name from the ref
          return unless elem.ref

          elem.ref.split(":").last
        end

        # Resolve attribute name from attribute (handles ref attribute)
        def resolve_attribute_name(attr)
          return attr.name if attr.name

          # Attribute uses ref - extract the local name from the ref
          return unless attr.ref

          attr.ref
        end

        # Collect all attributes from a type (including inherited)
        def collect_attributes(type)
          attrs = []

          # Direct attributes
          if type.attribute
            attrs.concat(type.attribute)
          end

          # Get attributes from attribute group ref
          attrs.concat(generate_attributes_from_group_ref(type))

          # Attributes from content
          attrs.concat(generate_attributes_from_content(type))

          attrs.uniq(&:name)
        end

        # Get base from extension
        def get_base_from_extension(type)
          base_val = nil
          %i[simple_content complex_content].each do |content_type|
            if type.public_send(content_type)
              sc = type.public_send(content_type)
              if sc.extension
                sc_ext = sc.extension
                if sc_ext.base
                  base_val = sc_ext.base
                end
              end
            end
          end

          base_val
        end

        # Get attributes from simple or complex content
        def generate_attributes_from_content(type)
          attrs = []
          %i[simple_content complex_content].each do |content_type|
            if type.public_send(content_type)
              sc = type.public_send(content_type)
              if sc.extension
                sc_ext = sc.extension

                # Get attributes from content extension
                if sc_ext.attribute
                  attrs.concat(sc_ext.attribute)
                end

                # Get attributes in attribute groups from content extension
                attrs.concat(generate_attributes_from_group_ref(sc_ext))
              elsif sc.restriction
                # Get attributes from content restriction
                if sc.restriction.attribute
                  attrs.concat(sc.restriction.attribute)
                end

                # Get attributes in attribute groups from restriction extension
                attrs.concat(generate_attributes_from_group_ref(sc.restriction))
              end
            end
          end
          attrs
        end

        # Get attributes from attribute group ref
        def generate_attributes_from_group_ref(model)
          attrs = []
          if model.attribute_group
            attrs.concat(
              generate_attributes_from_attribute_group_ref(
                model.attribute_group,
              ),
            )
          end
          attrs
        end

        # Get attributes from attribute group ref
        def generate_attributes_from_attribute_group_ref(attribute_group)
          attrs = []

          refs = attribute_group.filter_map(&:ref)
          refs.each do |ref|
            group = find_attribute_group(ref)
            if group
              attrs.concat(
                generate_attributes_from_attribute_group(group),
              )
            end
          end

          attrs
        end

        # Get attributes from attribute group
        def generate_attributes_from_attribute_group(attribute_group)
          attrs = []
          if attribute_group.attribute
            attrs.concat(attribute_group.attribute)
          end
          attrs
        end

        # Find an attribute group by name in the schema
        def find_attribute_group(ag_name)
          return nil unless ag_name

          # Search in current schema
          if @schema.attribute_group
            found = @schema.attribute_group.find { |t| t.name == ag_name }
            return found if found
          end

          nil
        end

        # Find a type by name in the schema
        def find_type(type_name)
          return nil unless type_name

          # Strip namespace prefix
          local_name = type_name.split(":").last

          # Search in current schema
          if @schema.complex_type
            found = @schema.complex_type.find { |t| t.name == local_name }
            return found if found
          end

          if @schema.simple_type
            found = @schema.simple_type.find { |t| t.name == local_name }
            return found if found
          end

          # Search in repository if available
          if @repository
            # Try to find type in all schemas
            all_schemas = @repository.all_schemas
            all_schemas.each_value do |schema|
              if schema.complex_type
                found = schema.complex_type.find { |t| t.name == local_name }
                return found if found
              end

              if schema.simple_type
                found = schema.simple_type.find { |t| t.name == local_name }
                return found if found
              end
            end
          end

          nil
        end

        # Generate content for an extension (combining base and extension elements)
        def generate_extension_content(extension, indent)
          lines = []
          indent_str = "  " * indent

          # Collect all elements from base type and extension into a single sequence
          all_elements = []

          # Get base type elements first
          if extension.base
            base_type = find_type(extension.base)
            all_elements.concat(collect_type_elements(base_type)) if base_type
          end

          # Then add extension elements
          if extension.sequence
            all_elements.concat(extension.sequence.element) if extension.sequence.element
          elsif extension.choice
            # Handle choice in extension
            return generate_choice_content(extension.choice, indent)
          elsif extension.all
            # Handle all in extension
            return generate_all_content(extension.all, indent)
          end

          # Display as a single combined sequence if we have elements
          if all_elements.any?
            lines << "#{indent_str}Start Sequence"

            all_elements.each do |elem|
              elem_occurs = element_occurs(elem)
              elem_name = resolve_element_name(elem)
              next unless elem_name

              elem_info = resolve_element_schema(elem_name)
              display_name = get_display_name_with_prefix(elem_info)
              lines << "#{indent_str}  <#{display_name}> ... </#{display_name}> #{elem_occurs}"
            end

            lines << "#{indent_str}End Sequence"
          end

          lines
        end

        # Collect all elements from a type recursively
        def collect_type_elements(type, visited = [])
          return [] if visited.include?(type.object_id)

          visited << type.object_id

          elements = []

          # Direct sequence elements
          elements.concat(type.sequence.element) if type.sequence&.element

          # Elements from complex_content extension
          if type.complex_content
            cc = type.complex_content
            if cc.extension
              # Get base type elements
              if cc.extension.base
                base_type = find_type(cc.extension.base)
                if base_type
                  elements.concat(collect_type_elements(base_type,
                                                        visited))
                end
              end

              # Get extension sequence elements
              elements.concat(cc.extension.sequence.element) if cc.extension.sequence&.element
            end
          end

          elements
        end

        # Generate choice content
        def generate_choice_content(choice, indent)
          lines = []
          indent_str = "  " * indent

          occurs = model_group_occurs(choice)
          lines << "#{indent_str}Start Choice #{occurs}"

          choice.element.each do |elem|
            elem_occurs = element_occurs(elem)
            elem_name = resolve_element_name(elem)
            next unless elem_name

            elem_info = resolve_element_schema(elem_name)
            display_name = get_display_name_with_prefix(elem_info)
            lines << "#{indent_str}  <#{display_name}> ... </#{display_name}> #{elem_occurs}"
          end

          lines << "#{indent_str}End Choice"
          lines
        end

        # Generate all content
        def generate_all_content(all_group, indent)
          lines = []
          indent_str = "  " * indent

          occurs = model_group_occurs(all_group)
          lines << "#{indent_str}Start All #{occurs}"

          all_group.element.each do |elem|
            elem_occurs = element_occurs(elem)
            elem_name = resolve_element_name(elem)
            next unless elem_name

            elem_info = resolve_element_schema(elem_name)
            display_name = get_display_name_with_prefix(elem_info)
            lines << "#{indent_str}  <#{display_name}> ... </#{display_name}> #{elem_occurs}"
          end

          lines << "#{indent_str}End All"
          lines
        end

        # Get schema ID for an element (for linking)
        def get_schema_id_for_element(_element)
          # Try to find which schema this element belongs to
          return nil unless @schema

          # Use schema's target namespace or filename to create schema ID
          return unless @schema.target_namespace

          # Extract last part of namespace as schema ID
          uri = @schema.target_namespace
          uri.split("/").last || uri.split(":").last
        end

        # Get link marker for an element with cross-schema support
        def get_element_link_marker(elem_name)
          # Resolve which schema defines this element
          elem_info = resolve_element_schema(elem_name)

          # Strip namespace prefix for link
          local_name = elem_info[:name]
          schema_id = elem_info[:schema_id]

          " data-element-ref=\"#{local_name}\" data-element-schema=\"#{schema_id}\""
        end

        # Resolve which schema defines an element
        def resolve_element_schema(elem_name)
          # Parse the element name - might have namespace prefix
          if elem_name.include?(":")
            prefix, local_name = elem_name.split(":", 2)

            # Find schema with this namespace prefix
            target_schema = find_schema_by_prefix(prefix)

            if target_schema
              return {
                schema: target_schema,
                schema_id: get_schema_id(target_schema),
                prefix: prefix,
                name: local_name,
              }
            end
          end

          # Element in same schema (no prefix or prefix not found)
          local_name = elem_name.split(":").last
          {
            schema: @schema,
            schema_id: get_schema_id(@schema),
            prefix: nil,
            name: local_name,
          }
        end

        # Find schema by namespace prefix
        def find_schema_by_prefix(prefix)
          return nil unless @all_schemas

          # Common namespace mappings
          namespace_uris = {
            "uro" => "https://www.geospatial.jp/iur/uro/3.2",
            "urf" => "https://www.geospatial.jp/iur/urf/3.2",
            "gml" => "http://www.opengis.net/gml/3.2",
            "xlink" => "http://www.w3.org/1999/xlink",
            "gco" => "http://www.isotc211.org/2005/gco",
          }

          namespace_uri = namespace_uris[prefix]
          return nil unless namespace_uri

          # Search all_schemas for one with matching target_namespace
          @all_schemas.each_value do |schema|
            if schema.target_namespace == namespace_uri
              return schema
            end
          end

          nil
        end

        # Get schema ID for a schema
        def get_schema_id(schema)
          return "unnamed" unless schema

          # Use target namespace to derive schema ID
          if schema.target_namespace
            uri = schema.target_namespace
            # Extract last part of namespace as schema ID (e.g., "uro/3.2" -> "uro")
            parts = uri.split("/")
            if parts.length >= 2
              name = parts[-2] # Get second-to-last part
              return slugify(name)
            end
            return slugify(parts.last || "unnamed")
          end

          "unnamed"
        end

        # Slugify helper
        def slugify(name)
          return "unnamed" unless name

          name.to_s
            .gsub(/([A-Z]+)([A-Z][a-z])/, '\1-\2')
            .gsub(/([a-z\d])([A-Z])/, '\1-\2')
            .downcase
            .gsub(/[^a-z0-9]+/, "-")
            .gsub(/^-|-$/, "")
        end

        # Get display name with namespace prefix if cross-schema
        def get_display_name_with_prefix(elem_info)
          if elem_info[:prefix] && elem_info[:schema_id] != get_schema_id(@schema)
            # Cross-schema element - show with prefix
            "#{elem_info[:prefix]}:#{elem_info[:name]}"
          else
            # Same schema element - no prefix
            elem_info[:name]
          end
        end

        # Get link marker for a type
        def get_type_link_marker(type_name)
          return "" unless type_name

          # Don't link built-in XSD types
          return "" if /^(xs:|xsd:|string|integer|boolean|date|time|anyURI|double|float|decimal)/.match?(type_name)

          # Strip namespace prefix for link
          local_name = type_name.split(":").last
          " data-type-ref=\"#{local_name}\""
        end
      end
    end
  end
end
