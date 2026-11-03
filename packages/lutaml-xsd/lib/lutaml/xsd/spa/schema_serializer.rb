# frozen_string_literal: true

require "json"
require "moxml"
require "tmpdir"
require "fileutils"
require "tempfile"
require "xsdvi"
require_relative "xml_instance_generator"
require_relative "utils/extract_enumeration"

module Lutaml
  module Xsd
    module Spa
      # Base class for schema serializers (Template Method Pattern)
      #
      # Defines the overall algorithm for serializing XSD schema repositories
      # into a format suitable for SPA documentation. Subclasses can override
      # specific steps to customize the serialization process.
      #
      # The serialization process follows these steps:
      # 1. Build metadata
      # 2. Serialize all schemas
      # 3. Build search index
      # 4. Assemble final structure
      #
      # @abstract Subclass and override template methods to customize
      #   serialization
      #
      # @example Using the serializer
      #   serializer = JsonSchemaSerializer.new(repository)
      #   data = serializer.serialize
      #   json = serializer.to_json
      class SchemaSerializer
        include ::Lutaml::Xsd::Spa::Utils::ExtractEnumeration

        # Fields to merge when combining schemas with the same targetNamespace
        MERGEABLE_CONTENT_FIELDS = %i[
          elements complex_types simple_types
          attributes groups attribute_groups
        ].freeze

        attr_reader :repository, :config, :package

        # Initialize schema serializer
        #
        # @param repository_or_package [SchemaRepository, SchemaRepositoryPackage] Schema repository or package to serialize
        # @param config [Hash] Configuration options
        def initialize(repository_or_package, config = {})
          if repository_or_package.is_a?(SchemaRepositoryPackage)
            @package = repository_or_package
            @repository = repository_or_package.repository
          else
            @repository = repository_or_package
            @package = nil
          end
          @config = config
        end

        # Serialize repository to data structure (template method)
        #
        # This method defines the overall algorithm for serialization.
        # Subclasses can override individual steps as needed.
        #
        # @return [Hash] Serialized data structure
        def serialize
          metadata = build_metadata
          # Convert SpaMetadata model to hash for JSON serialization
          # SpaMetadata.to_hash returns string keys, but we need symbol keys for compatibility
          hash = metadata.to_hash
          metadata_hash = hash.to_h do |k, v|
            [k.is_a?(String) ? k.to_sym : k, v]
          end
          {
            metadata: metadata_hash,
            schemas: serialize_schemas,
            namespaces: build_namespaces,
            index: build_index,
          }
        end

        # Convert serialized data to JSON string
        #
        # @param pretty [Boolean] Whether to pretty-print JSON
        # @return [String] JSON string
        def to_json(pretty: true)
          data = serialize
          pretty ? JSON.pretty_generate(data) : JSON.generate(data)
        end

        protected

        # Build metadata section (template method hook)
        #
        # Subclasses can override to customize metadata
        #
        # @return [SpaMetadata] SpaMetadata model instance
        def build_metadata
          pkg_meta = @package&.metadata

          # Extract metadata from package (supports both Hash-like and Lutaml::Model objects)
          pkg_hash = if pkg_meta.is_a?(Hash)
                       pkg_meta
                     elsif pkg_meta
                       pkg_meta.to_h
                     else
                       {}
                     end

          title = pkg_hash[:title] || pkg_hash["title"] ||
            pkg_hash[:name] || pkg_hash["name"] ||
            config["title"] || default_title

          SpaMetadata.new(
            generated: current_timestamp,
            generator: generator_info,
            title: title,
            name: pkg_hash[:name] || pkg_hash["name"],
            version: pkg_hash[:version] || pkg_hash["version"],
            description: pkg_hash[:description] || pkg_hash["description"],
            homepage: pkg_hash[:homepage] || pkg_hash["homepage"],
            documentation: pkg_hash[:documentation] || pkg_hash["documentation"],
            license: pkg_hash[:license] || pkg_hash["license"],
            license_url: (pkg_hash[:license_url] || pkg_hash["license_url"]).then do |v|
              v.is_a?(String) && !v.empty? ? v : nil
            end,
            authors: pkg_hash[:authors] || pkg_hash["authors"],
            repository: pkg_hash[:repository] || pkg_hash["repository"],
            tags: pkg_hash[:tags] || pkg_hash["tags"] || [],
            appearance: pkg_hash[:appearance] || pkg_hash["appearance"],
            links: pkg_hash[:links] || pkg_hash["links"],
            schema_count: get_schemas.size,
          )
        end

        # Build a URI => prefix lookup from repository namespace_mappings
        #
        # @return [Hash] Map of namespace URI to registered prefix
        def namespace_prefix_lookup
          return @namespace_prefix_lookup if defined?(@namespace_prefix_lookup) && @namespace_prefix_lookup

          @namespace_prefix_lookup = {}
          if repository.namespace_mappings && !repository.namespace_mappings.empty?
            repository.namespace_mappings.each do |mapping|
              if mapping.uri && mapping.prefix
                @namespace_prefix_lookup[mapping.uri] =
                  mapping.prefix
              end
            end
          end
          @namespace_prefix_lookup
        end

        # Build namespaces section from all schemas
        #
        # @return [Array<Hash>] Array of namespace hashes with prefix, uri, schemas
        def build_namespaces
          ns_map = {}
          get_schemas.each do |file_path, schema|
            next unless schema

            ns = schema.target_namespace
            if ns
              prefix = namespace_prefix_lookup[ns] || derive_prefix(ns, schema)
              ns_map[ns] ||= { prefix: prefix, uri: ns, schemas: [] }
              ns_map[ns][:schemas] << schema_id(nil, schema, file_path)
            else
              ns_map["__default__"] ||= { prefix: "tns", uri: "", schemas: [] }
              ns_map["__default__"][:schemas] << schema_id(nil, schema,
                                                           file_path)
            end
          end
          ns_map.values
        end

        # Derive a short prefix from a namespace URI
        #
        # @param ns [String] Namespace URI
        # @param _schema [Schema] Schema object (unused)
        # @return [String] Derived prefix
        def derive_prefix(ns, _schema)
          return "tns" if ns.nil? || ns.empty?

          # Detect standard XML Schema namespace using parsed URI components
          begin
            uri = URI(ns)
            if uri&.host && %w[w3.org
                               www.w3.org].include?(uri.host) && uri.path&.include?("XMLSchema")
              return "xs"
            end
          rescue URI::InvalidURIError
            # Fall back to other heuristics below if the namespace is not a valid URI
          end

          return "gml" if ns.include?("/gml/")

          # Try to extract a meaningful prefix from the URI path
          # e.g. "http://www.opengis.net/citygml/2.0" => "citygml"
          # e.g. "http://example.com/my-schema" => "myschema"
          host_stripped = ns.sub(%r{^https?://}, "")
          path = host_stripped.sub(%r{^[^/]+}, "")
          segments = path.split("/").reject(&:empty?)
          # Use the last non-numeric segment as prefix
          prefix_segment = segments.reverse.find { |s| !s.match?(/\A[\d.]+\z/) }
          prefix_segment&.gsub(/[^a-zA-Z0-9]/, "")&.downcase || "tns"
        end

        # Serialize all schemas (template method hook)
        #
        # @return [Array<Hash>] Array of serialized schemas
        def serialize_schemas
          schemas_data = get_schemas.map.with_index do |(file_path, schema), index|
            serialize_schema(schema, index, file_path)
          end.compact

          # Merge schemas that share the same target namespace (from <include>)
          # XSD <include> merges included schemas into the same namespace.
          # Group by namespace, keep entry point as primary, merge content from others.
          schemas_data = merge_included_schemas(schemas_data)

          # Post-process: add used_by reverse references
          attach_used_by_references(schemas_data)

          schemas_data
        end

        # Merge schemas sharing the same targetNamespace (from <include> directives)
        #
        # In XSD, <include> means the included schema targets the same namespace.
        # These should appear as a single merged schema in the SPA, not as
        # separate empty + populated entries.
        #
        # Schemas with nil namespace (chameleon schemas) are NOT merged since
        # they adopt the namespace of their including schema at parse time.
        #
        # @param schemas_data [Array<Hash>] Serialized schema data
        # @return [Array<Hash>] Merged schema data
        def merge_included_schemas(schemas_data)
          return schemas_data if schemas_data.length <= 1

          ns_groups = {}
          schemas_data.each do |schema|
            ns = schema[:namespace]
            # Skip nil-namespace schemas — chameleon schemas should not be merged
            next unless ns

            ns_groups[ns] ||= []
            ns_groups[ns] << schema
          end

          # Collect schemas that were NOT grouped (nil namespace)
          merged_schemas = schemas_data.reject { |s| s[:namespace] }

          ns_groups.each_value do |group|
            if group.length == 1
              merged_schemas << group.first
              next
            end

            primary = group.find { |s| s[:is_entrypoint] }
            primary ||= group.max_by { |s| content_weight(s) }
            secondaries = group.reject { |s| s[:id] == primary[:id] }

            merge_content_into!(primary, secondaries)
            merged_schemas << primary
          end

          merged_schemas
        end

        # Measure content richness of a serialized schema for primary selection
        #
        # @param schema [Hash] Serialized schema data
        # @return [Integer] Total item count across content fields
        def content_weight(schema)
          MERGEABLE_CONTENT_FIELDS.sum { |f| (schema[f] || []).length }
        end

        # Merge content arrays from secondary schemas into the primary schema
        #
        # Uses Set for O(1) deduplication by hash identity.
        #
        # @param primary [Hash] Primary schema to merge into (mutated)
        # @param secondaries [Array<Hash>] Secondary schemas to absorb
        # @return [void]
        def merge_content_into!(primary, secondaries)
          MERGEABLE_CONTENT_FIELDS.each do |field|
            primary[field] ||= []
            seen = primary[field].to_set
            secondaries.each do |sec|
              (sec[field] || []).each do |item|
                primary[field] << item unless seen.include?(item)
              end
            end
          end

          # Merge includes and imports (deduplicated by hash equality)
          %i[includes imports].each do |field|
            primary[field] ||= []
            seen = primary[field].to_set
            secondaries.each do |sec|
              (sec[field] || []).each do |item|
                primary[field] << item unless seen.include?(item)
              end
            end
          end

          # Collect all file paths
          all_paths = [primary[:file_path]]
          secondaries.each { |s| all_paths << s[:file_path] if s[:file_path] }
          primary[:file_paths] = all_paths.compact
        end

        # Serialize single schema (template method hook)
        #
        # Subclasses should override to customize schema serialization
        #
        # @param schema [Schema] Schema object
        # @param index [Integer] Schema index
        # @param file_path [String] Schema file path
        # @return [Hash] Serialized schema
        def serialize_schema(schema, index, file_path = nil)
          return nil unless schema

          schema_source = if file_path
                            begin
                              File.read(file_path)
                            rescue StandardError
                              nil
                            end
                          end

          prefix = namespace_prefix_lookup[schema.target_namespace] || derive_prefix(
            schema.target_namespace, schema
          )
          {
            id: schema_id(index, schema, file_path),
            name: schema_name(schema, file_path),
            prefix: prefix,
            namespace: schema.target_namespace,
            file_path: clean_file_path(file_path),
            is_entrypoint: is_entrypoint?(file_path),
            elements: serialize_elements(
              schema, prefix, schema_source, file_path
            ),
            complex_types: serialize_complex_types(
              schema, prefix, schema_source, file_path
            ),
            simple_types: serialize_simple_types(schema, prefix),
            attributes: serialize_attributes(schema, prefix),
            groups: serialize_groups(schema, prefix),
            attribute_groups: serialize_attribute_groups(
              schema, prefix, schema_source
            ),
            imports: serialize_imports(schema),
            includes: serialize_includes(schema),
          }
        end

        # Build search index (template method hook)
        #
        # Subclasses can override to customize indexing
        #
        # @return [Hash] Search index
        def build_index
          {
            by_id: build_id_index,
            by_name: build_name_index,
            by_type: build_type_index,
          }
        end

        # Serialize elements from schema
        #
        # @param schema [Schema] Schema object
        # @param prefix [String, nil] Optional prefix for IDs
        # @param schema_source [String, nil] Optional schema source for context
        # @param file_path [String, nil] Optional schema file path
        # @return [Array<Hash>] Serialized elements (sorted alphabetically by name)
        def serialize_elements(schema,
          prefix = nil, schema_source = nil, file_path = nil)
          schema.elements.map.with_index do |element, index|
            serialize_element(element, index, prefix, schema_source, file_path)
          end.sort_by { |e| e[:name] || "" }
        end

        # Serialize single element
        #
        # @param element [Element] Element object
        # @param index [Integer] Element index
        # @param prefix [String, nil] Optional prefix for IDs
        # @param schema_source [String, nil] Optional schema source for context
        # @param file_path [String, nil] Optional schema file path
        # @return [Hash] Serialized element
        def serialize_element(element, index,
          prefix = nil, schema_source = nil, file_path = nil)
          element_data = {
            id: element_id(index, element, prefix),
            name: element.name,
            type: element.type,
            min_occurs: element.min_occurs,
            max_occurs: element.max_occurs,
            occurs: {
              min: element.min_occurs || 1,
              max: element.max_occurs || 1,
            },
            documentation: extract_documentation(element),
            instance_xml: generate_instance_xml(element),
            source: extract_source_by_type_key_value(
              "element", "name", element.name, prefix, schema_source
            ),
          }

          # Enriched fields
          element_data[:ref] = element.ref if element.ref
          element_data[:nillable] = element.nillable if element.nillable
          element_data[:abstract] = element.abstract if element.abstract
          if element.substitution_group
            element_data[:substitution_group] =
              element.substitution_group
          end
          element_data[:default] = element.default if element.default
          element_data[:fixed] = element.fixed if element.fixed

          # Add SVG diagram
          element_data[:diagram_svg] =
            generate_diagram(element_data, :element, file_path)

          element_data
        end

        def gen_element_diagram(name, file_path, component_type = :element)
          if !file_path || !File.exist?(file_path)
            warn "xsdvi: XSD file '#{file_path}' not found" if config[:verbose]
            return nil
          end

          actual_file_path = file_path
          wrapper_name = name

          if component_type == :type
            # For types, create a temporary XSD with a synthetic wrapper element
            # so xsdvi can treat the type as a root element
            actual_file_path = create_type_wrapper_xsd(name, file_path)
            wrapper_name = "_diagram_root_#{name}"
          end

          output_folder = Dir.mktmpdir("xsdvi-")
          svg_file = File.join(output_folder, "#{name}.svg")

          # Use xsdvi Ruby API directly instead of CLI
          builder = Xsdvi::Tree::Builder.new
          xsd_handler = Xsdvi::XsdHandler.new(builder)
          writer_helper = Xsdvi::Utils::Writer.new
          svg_generator = Xsdvi::SVG::Generator.new(writer_helper)

          svg_generator.hide_menu_buttons = true
          svg_generator.embody_style = true

          xsd_handler.root_node_name = wrapper_name
          xsd_handler.one_node_only = true
          xsd_handler.process_file(actual_file_path)

          unless builder.root
            warn "xsdvi: SVG not generated for '#{name}'" if config[:verbose]
            return nil
          end

          writer_helper.new_writer(svg_file)
          svg_generator.draw(builder.root)

          return nil unless File.exist?(svg_file)

          # read generated SVG content
          svg_content = File.read(svg_file)

          # Strip XML declaration and DOCTYPE for embedding in HTML
          svg_content = svg_content
            .gsub(/<\?xml[^?]*\?>\s*/i, "")
            .gsub(/<!DOCTYPE[^>]*>\s*/i, "")
            .gsub(/<title>.*?<\/title>/i, "") # Remove title element if present
            .gsub(/<script[^>]*>.*?<\/script>/im, "") # Remove any script
            .gsub(/<a[^>]*>(.*?)<\/a>/im, '\1') # Remove links but keep content

          svg_content
        rescue StandardError => e
          warn "xsdvi: Failed to generate diagram for '#{name}': #{e.message}" if config[:verbose]
          nil
        ensure
          FileUtils.rm_rf(output_folder) if output_folder
          if component_type == :type && actual_file_path && actual_file_path != file_path
            FileUtils.rm_f(actual_file_path)
          end
        end

        public

        # Create a temporary XSD file that wraps a complexType/simpleType
        # in a synthetic root element, so xsdvi can generate a diagram for it.
        #
        # @param type_name [String] The type name
        # @param original_file_path [String] Path to the original XSD file
        # @return [String] Path to the temporary XSD file
        def create_type_wrapper_xsd(type_name, original_file_path)
          doc = Moxml::Context.new.parse(File.read(original_file_path))
          ns = { "xs" => "http://www.w3.org/2001/XMLSchema" }
          schema = doc.at_xpath("//xs:schema", ns)

          unless schema
            warn "xsdvi: No xs:schema found in '#{original_file_path}'" if config[:verbose]
            return original_file_path
          end

          wrapper_name = "_diagram_root_#{type_name}"

          # Check if this type might need a namespace prefix
          # Look for how the type is referenced in the original schema
          type_ref = resolve_type_prefix(type_name, doc, ns)

          # Create element with proper XSD namespace from the schema
          xsd_ns = "http://www.w3.org/2001/XMLSchema"
          xsd_ns_decl = schema.namespace_definitions.find do |nd|
            nd.uri == xsd_ns
          end

          element_node = doc.create_element("element")
          element_node.namespace = xsd_ns_decl if xsd_ns_decl
          element_node["name"] = wrapper_name
          element_node["type"] = type_ref

          schema.add_child(element_node)

          tmp = Tempfile.new(["xsdvi-wrapper-", ".xsd"])
          tmp.write(doc.to_xml)
          tmp.close
          tmp.path
        end

        # Determine the correct type reference prefix for a type in the schema.
        # If the type is defined in the targetNamespace, use the same prefix
        # that the schema uses internally for its targetNamespace.
        #
        # @param type_name [String] The type name
        # @param doc [Moxml::Document] The parsed XSD document
        # @param ns [Hash] Namespace mapping
        # @return [String] The type reference string (possibly prefixed)
        def resolve_type_prefix(type_name, doc, ns)
          schema = doc.at_xpath("//xs:schema", ns)
          target_ns = schema["targetNamespace"]

          # Check if the type is defined in this schema's targetNamespace
          type_in_schema = doc.xpath("//xs:complexType[@name='#{type_name}']",
                                     ns).any? ||
            doc.xpath("//xs:simpleType[@name='#{type_name}']",
                      ns).any?

          return type_name unless type_in_schema && target_ns

          # Find what prefix maps to the targetNamespace
          ns_decls = schema.namespace_definitions
          tns_prefix = ns_decls.find do |nd|
            nd.uri == target_ns && nd.prefix
          end

          tns_prefix ? "#{tns_prefix.prefix}:#{type_name}" : type_name
        end

        protected

        # Serialize complex types from schema
        #
        # @param schema [Schema] Schema object
        # @param prefix [String, nil] Optional prefix for IDs
        # @param schema_source [String, nil] Optional schema source for context
        # @return [Array<Hash>] Serialized complex types (sorted alphabetically by name)
        def serialize_complex_types(schema, prefix = nil, schema_source = nil,
file_path = nil)
          return [] unless schema.is_a?(Lutaml::Xml::Schema::Xsd::Schema)

          types = schema.complex_types
          serialized = types.map.with_index do |type, index|
            serialize_complex_type(
              type, index, prefix, schema_source, file_path
            )
          end

          # Also serialize inline/anonymous complex types from elements
          serialized.concat(serialize_inline_complex_types(schema, prefix, schema_source, file_path))

          serialized.sort_by { |t| t[:name] || "" }
        end

        # Serialize inline/anonymous complex types defined within elements
        #
        # @param schema [Schema] Schema object
        # @param prefix [String, nil] Optional prefix for IDs
        # @param schema_source [String, nil] Optional schema source for context
        # @param file_path [String, nil] Optional file path for diagram generation
        # @return [Array<Hash>] Serialized inline complex types
        def serialize_inline_complex_types(schema, prefix = nil, _schema_source = nil, _file_path = nil)
          return [] unless schema.element

          elements = schema.element.is_a?(Array) ? schema.element : [schema.element]
          inline_types = []

          elements.compact.each do |element|
            next unless element.complex_type
            next if element.complex_type.name # Skip if already named (top-level)

            # Generate a synthetic name for the inline type
            inline_name = "#{element.name}_type"

            inline_types << {
              id: "type-#{prefix}-#{slugify(inline_name)}",
              name: inline_name,
              base: nil,
              content_model: extract_content_model(element.complex_type),
              abstract: element.complex_type.abstract || false,
              mixed: element.complex_type.mixed || false,
              attributes: serialize_type_attributes(element.complex_type),
              elements: serialize_type_elements(element.complex_type),
              choice: serialize_choice(element.complex_type.choice),
              sequence: serialize_sequence(element.complex_type.sequence),
              group: serialize_type_group(element.complex_type.group),
              attribute_groups: serialize_type_attr_groups(element.complex_type),
              documentation: extract_documentation(element.complex_type),
              instance_xml: nil,
              source: nil,
              diagram_svg: nil,
              inline_of_element: element.name,
              used_by: [],
            }
          end

          inline_types
        end

        # Serialize single complex type
        #
        # @param type [ComplexType] Complex type object
        # @param index [Integer] Type index
        # @return [Hash] Serialized complex type
        def serialize_complex_type(type, index, prefix = nil,
schema_source = nil, file_path = nil)
          return nil unless type

          content_model = extract_content_model(type)
          type_data = {
            id: complex_type_id(index, type, prefix),
            name: type.name,
            base: extract_base_type(type),
            content_model: content_model,
            abstract: type.abstract || false,
            mixed: type.mixed || false,
            attributes: serialize_type_attributes(type),
            elements: serialize_type_elements(type),
            choice: serialize_choice(type.choice),
            sequence: serialize_sequence(type.sequence),
            group: serialize_type_group(type.group),
            attribute_groups: serialize_type_attr_groups(type),
            documentation: extract_documentation(type),
            instance_xml: generate_instance_xml(type),
            source: extract_source_by_type_key_value(
              "complexType", "name", type.name, prefix, schema_source
            ),
          }

          # Collect attributes from inside extension for simpleContent/complexContent
          extension_attrs = collect_extension_attributes(type)
          unless extension_attrs.empty?
            type_data[:extension_attributes] =
              extension_attrs
          end

          # Add SVG diagram
          type_data[:diagram_svg] =
            generate_diagram(type_data, :type, file_path)

          type_data
        end

        # Serialize a single choice model
        #
        # @param choice [Object] Choice object from the schema
        # @return [Hash] Serialized choice
        def serialize_choice(choice)
          return nil unless choice

          {
            id: choice.id,
            occurs: {
              min: choice.min_occurs || 1,
              max: choice.max_occurs || 1,
            },
            documentation: extract_documentation(choice),
            groups: serialize_type_groups(choice),
            elements: serialize_type_elements(choice),
            sequences: serialize_sequences(choice),
            choices: serialize_choices(choice),
          }
        end

        # Serialize choice models
        #
        # @param model [Object] Model that may contain choice
        # @return [Array<Hash>] Serialized choices
        def serialize_choices(model)
          return [] unless model.choice

          model_choices = if model.choice.is_a?(Array)
                            model.choice
                          else
                            [model.choice]
                          end
          model_choices.compact.map do |nc|
            serialize_choice(nc)
          end
        end

        # Serialize a single sequence model
        #
        # @param sequence [Object] Sequence object from the schema
        # @return [Hash] Serialized sequence
        def serialize_sequence(sequence)
          return nil unless sequence

          {
            id: sequence.id,
            occurs: {
              min: sequence.min_occurs || 1,
              max: sequence.max_occurs || 1,
            },
            documentation: extract_documentation(sequence),
            sequences: serialize_sequences(sequence),
            elements: serialize_type_elements(sequence),
            choices: serialize_choices(sequence),
            groups: serialize_type_groups(sequence),
          }
        end

        # Serialize sequence models
        #
        # @param model [Object] Model that may contain sequence
        # @return [Array<Hash>] Serialized sequences
        def serialize_sequences(model)
          return [] unless model.sequence

          model_sequences = if model.sequence.is_a?(Array)
                              model.sequence
                            else
                              [model.sequence]
                            end
          model_sequences.compact.map do |nc|
            serialize_sequence(nc)
          end
        end

        # Collect attributes from inside extension element
        #
        # @param type [ComplexType] Complex type object
        # @return [Array<Hash>] Serialized extension attributes
        def collect_extension_attributes(type)
          attrs = []

          # Check simpleContent.extension
          if type.simple_content
            sc = type.simple_content
            if sc.extension
              ext = sc.extension
              attrs.concat(collect_from_extension(ext))
            end
          end

          # Check complexContent.extension
          if type.complex_content
            cc = type.complex_content
            if cc.extension
              ext = cc.extension
              attrs.concat(collect_from_extension(ext))
            end
          end

          attrs
        end

        # Collect attributes from an extension element
        #
        # @param extension [Object] Extension object
        # @return [Array<Hash>] Serialized attributes
        def collect_from_extension(extension)
          attrs = []

          # Direct attributes
          if extension.attribute && !extension.attribute.empty?
            extension.attribute.each do |attr|
              attr_name = attr.name || attr.ref
              attrs << {
                name: attr_name,
                ref: attr.ref,
                type: attr.type,
                use: attr.use,
              }
            end
          end

          # Attribute groups
          if extension.attribute_group && !extension.attribute_group.empty?
            extension.attribute_group.each do |ag|
              ag_name = ag.ref || ag.name
              if ag_name
                # Look up attributes from the attribute group definition
                looked_up_attrs = lookup_attribute_group_attributes(ag_name)
                looked_up_attrs.each do |looked_attr|
                  attrs << looked_attr.merge({ attribute_group_ref: ag_name })
                end
              end
            end
          end

          attrs
        end

        # Serialize simple types from schema
        #
        # @param schema [Schema] Schema object
        # @param prefix [String, nil] Optional prefix for IDs
        # @return [Array<Hash>] Serialized simple types (sorted alphabetically by name)
        def serialize_simple_types(schema, prefix = nil)
          schema.simple_types.map.with_index do |type, index|
            serialize_simple_type(type, index, prefix)
          end.sort_by { |t| t[:name] || "" }
        end

        # Serialize single simple type
        #
        # @param type [SimpleType] Simple type object
        # @param index [Integer] Type index
        # @return [Hash] Serialized simple type
        def serialize_simple_type(type, index, prefix = nil)
          {
            id: simple_type_id(index, type, prefix),
            name: type.name,
            base: extract_simple_base(type),
            restriction: serialize_restriction(type),
            union: extract_union_members(type),
            list: extract_list_type(type),
            documentation: extract_documentation(type),
            instance_xml: generate_instance_xml(type),
          }
        end

        # Serialize attributes from schema
        #
        # @param schema [Schema] Schema object
        # @return [Array<Hash>] Serialized attributes
        def serialize_attributes(schema, prefix = nil)
          schema.attributes.map.with_index do |attr, index|
            serialize_attribute(attr, index, prefix)
          end
        end

        # Serialize single attribute
        #
        # @param attr [Attribute] Attribute object
        # @param index [Integer] Attribute index
        # @return [Hash] Serialized attribute
        def serialize_attribute(attr, index, prefix = nil)
          {
            id: attribute_id(index, attr, prefix),
            name: attr.name,
            type: attr.type,
            use: attr.use,
            default: attr.default,
            documentation: extract_documentation(attr),
          }
        end

        # Serialize groups from schema
        #
        # @param schema [Schema] Schema object
        # @return [Array<Hash>] Serialized groups
        def serialize_groups(schema, prefix = nil)
          return [] unless schema.groups

          grps = schema.groups
          grps.map.with_index do |group, index|
            # serialize_group(group, index, prefix)
            serialize_type_group(group, index, prefix)
          end.sort_by { |g| g[:name] || "" }
        end

        # Serialize single group
        #
        # @param group [Group] Group object
        # @param index [Integer] Group index
        # @return [Hash] Serialized group
        def serialize_group(group, index, prefix = nil)
          {
            id: group_id(index, group, prefix),
            name: group.name,
            elements: serialize_group_elements(group),
            attributes: serialize_group_attributes(group),
            documentation: extract_documentation(group),
            choice: serialize_choice(group.choice),
            sequence: serialize_sequence(group),
          }
        end

        # Serialize attribute groups from schema
        #
        # @param schema [Schema] Schema object
        # @param prefix [String, nil] Optional prefix for IDs
        # @param schema_source [String, nil] Optional schema source for context
        # @return [Array<Hash>] Serialized attribute groups (sorted alphabetically by name)
        def serialize_attribute_groups(schema, prefix = nil,
schema_source = nil)
          groups = schema.attribute_group
          return [] if groups.nil? || groups.empty?

          groups.map do |ag|
            id_prefix = prefix ? "attrgroup-#{prefix}-" : "attrgroup-"
            {
              id: "#{id_prefix}#{slugify(ag.name)}",
              name: ag.name,
              attributes: serialize_ag_attributes(ag),
              documentation: extract_documentation(ag),
              source: extract_source_by_type_key_value(
                "attributeGroup", "name", ag.name, prefix, schema_source
              ),
              instance_xml: generate_instance_xml(ag),
            }
          end.sort_by { |ag| ag[:name] || "" }
        end

        # Extract source XML for a schema component identified by type, key, value
        #
        # @param type [String] XSD element type name (e.g., "attributeGroup")
        # @param key [String] Attribute name to match on (e.g., "name")
        # @param value [String] Attribute value to match
        # @param prefix [String, nil] Optional namespace prefix
        # @param source [String, nil] Raw XSD source XML
        # @return [String, nil] Extracted source XML or nil
        def extract_source_by_type_key_value(type, key, value, prefix = nil,
source = nil)
          return nil unless source && value

          begin
            doc = Moxml::Context.new.parse(source)
            escaped_value = value.gsub("'", "''")
            xpath = if prefix
                      "//#{prefix}:#{type}[@#{key}='#{escaped_value}']"
                    else
                      "//#{type}[@#{key}='#{escaped_value}']"
                    end
            node = doc.at_xpath(xpath)
            # Element-level indentation is rejected by the leptris adapter
            # (moxml 0.5.150+); fragments keep their source whitespace.
            node&.to_xml
          rescue StandardError
            nil
          end
        end

        # Serialize attributes from an attribute group
        #
        # @param ag [AttributeGroup] Attribute group
        # @return [Array<Hash>] Serialized attributes
        def serialize_ag_attributes(ag)
          return [] unless ag.attribute && !ag.attribute.empty?

          ag.attribute.map do |attr|
            # Check for inline simpleType with enumeration
            enum_default, enum_type = extract_enumeration_default(attr)
            {
              name: attr.name || "#{attr.ref} (ref)",
              type: enum_type || attr.type,
              use: attr.use,
              default: enum_default || attr.default,
              fixed: attr.fixed,
              documentation: extract_documentation(attr),
            }
          end
        end

        # Serialize imports from schema
        #
        # @param schema [Schema] Schema object
        # @return [Array<Hash>] Serialized imports
        def serialize_imports(schema)
          return [] unless schema.imports && !schema.imports.empty?

          schema.imports.filter_map do |imp|
            {
              namespace: imp.namespace,
              schema_location: imp.schema_path,
            }
          end
        end

        # Serialize includes from schema
        #
        # @param schema [Schema] Schema object
        # @return [Array<Hash>] Serialized includes
        def serialize_includes(schema)
          return [] unless schema.includes && !schema.includes.empty?

          schema.includes.filter_map do |inc|
            {
              schema_location: inc.schema_path,
            }
          end
        end

        # Serialize elements within a group
        #
        # @param group [Group] Group object
        # @return [Array<Hash>] Serialized elements
        def serialize_group_elements(group)
          elements = []
          if group.elements && !group.elements.empty?
            elements = group.elements.map do |elem|
              {
                name: elem.name,
                type: elem.type,
                min_occurs: elem.min_occurs,
                max_occurs: elem.max_occurs,
                occurs: {
                  min: elem.min_occurs || 1,
                  max: elem.max_occurs || 1,
                },
                reference: elem.ref,
                documentation: extract_documentation(elem),
              }
            end
          end
          elements
        end

        # Serialize attributes within a group
        #
        # @param group [Group] Group object
        # @return [Array<Hash>] Serialized attributes
        def serialize_group_attributes(group)
          attrs = []
          if group.attributes && !group.attributes.empty?
            attrs = group.attributes.map do |attr|
              {
                name: attr.name,
                type: attr.type,
                use: attr.use,
                default: attr.default,
                fixed: attr.fixed,
                documentation: extract_documentation(attr),
              }
            end
          end
          attrs
        end

        # Serialize single group from model (complex type, choice, or sequence)
        #
        # @param type [ComplexType] Complex type
        # @return [Array<Hash>] Serialized group references
        def serialize_type_group_refs(type)
          return [] unless type.group

          groups = type.group.is_a?(Array) ? type.group : [type.group]
          groups.filter_map do |g|
            {
              ref: g.ref || g.name,
              min_occurs: g.min_occurs,
              max_occurs: g.max_occurs,
            }
          end
        end

        # @param model [ComplexType|Choice|Sequence]
        # @return [Array<Hash>] Serialized group
        def serialize_type_group(model, index = 0, prefix = nil)
          return nil if model.nil?

          {
            id: group_id(index, model, prefix),
            ref: model.ref,
            name: model.name,
            occurs: {
              min: model.min_occurs || 1,
              max: model.max_occurs || 1,
            },
            choice: serialize_choice(model.choice),
            sequence: serialize_sequence(model.sequence),
            documentation: extract_documentation(model),
          }
        end

        # Serialize group models
        #
        # @param model [Object] Model that may contain group
        # @return [Array<Hash>] Serialized groups
        def serialize_type_groups(model)
          return [] unless model.group

          model_groups = if model.group.is_a?(Array)
                           model.group
                         else
                           [model.group]
                         end
          model_groups.compact.map.with_index do |item, index|
            serialize_type_group(item, index)
          end
        end

        # Collect attribute group references from a content wrapper
        # (simpleContent/complexContent — both declare extension and
        # restriction); the extensions carry the attribute groups.
        #
        # @param model [SimpleContent, ComplexContent] Content wrapper
        # @return [Array<Object>] Collected attribute group reference objects
        def collect_attribute_group_refs(model)
          refs = []

          %i[extension restriction].each do |kind|
            part = model.public_send(kind)
            refs.concat(collect_extension_attribute_group_refs(part)) if part
          end

          refs
        end

        # Collect attribute group refs from an extension object
        #
        # Extension objects (ExtensionSimpleContent, ExtensionComplexContent) have
        # attribute_group but not extension, so recursion stops here.
        #
        # @param extension [ExtensionSimpleContent, ExtensionComplexContent] Extension object
        # @return [Array<Object>] Collected attribute group reference objects
        def collect_extension_attribute_group_refs(extension)
          refs = []
          if extension.attribute_group && !extension.attribute_group.empty?
            groups = extension.attribute_group.is_a?(Array) ? extension.attribute_group : [extension.attribute_group]
            refs.concat(groups)
          end
          refs
        end

        # Serialize attribute group references from a complex type
        #
        # Collects attribute group refs from three possible locations:
        # 1. Direct attribute groups on the type
        # 2. Inside simpleContent.extension
        # 3. Inside complexContent.extension
        #
        # @param type [ComplexType] Complex type
        # @return [Array<Hash>] Serialized attribute group references with attributes
        def serialize_type_attr_groups(type)
          return [] unless type

          all_ag_refs = []

          if type.attribute_group && !type.attribute_group.empty?
            all_ag_refs.concat(type.attribute_group)
          end

          if type.simple_content
            all_ag_refs.concat(collect_attribute_group_refs(type.simple_content))
          end

          if type.complex_content
            all_ag_refs.concat(collect_attribute_group_refs(type.complex_content))
          end

          return [] if all_ag_refs.empty?

          all_ag_refs.filter_map do |ag|
            ag_name = ag.ref || ag.name
            next unless ag_name

            attrs = lookup_attribute_group_attributes(ag_name)
            { ref: ag_name, attributes: attrs }
          end
        end

        # Look up attributes from an attribute group definition
        #
        # @param ag_name [String] Attribute group name
        # @return [Array<Hash>] Serialized attributes
        def lookup_attribute_group_attributes(ag_name)
          clean_name = ag_name.split(":").last
          get_schemas.each_value do |schema|
            next unless schema.attribute_group && !schema.attribute_group.empty?

            found_ag = schema.attribute_group.find do |group|
              [clean_name, ag_name].include?(group.name)
            end
            if found_ag&.attribute
              return serialize_ag_attributes(found_ag)
            end
          end
          []
        end

        # Extract union member types from simple type
        #
        # @param type [SimpleType] Simple type
        # @return [Array<String>, nil] Union member type names
        def extract_union_members(type)
          return nil unless type.union

          union = type.union
          if union.member_types && !union.member_types.empty?
            union.member_types.is_a?(String) ? union.member_types.split : union.member_types
          elsif union.simple_type && !union.simple_type.empty?
            union.simple_type.filter_map(&:name)
          end
        end

        # Extract list item type from simple type
        #
        # @param type [SimpleType] Simple type
        # @return [String, nil] List item type name
        def extract_list_type(type)
          return nil unless type.list

          list = type.list
          list.item_type
        end

        # Build used_by reverse references across all schemas
        #
        # @param schemas_data [Array<Hash>] Serialized schema data
        # @return [void]
        def attach_used_by_references(schemas_data)
          used_by = build_used_by_index(schemas_data)
          schemas_data.each do |schema_data|
            (schema_data[:complex_types] || []).each do |type|
              type[:used_by] = used_by[type[:name]] || []
            end
            (schema_data[:simple_types] || []).each do |type|
              type[:used_by] = used_by[type[:name]] || []
            end
            (schema_data[:attribute_groups] || []).each do |ag|
              ag[:used_by] = used_by[ag[:name]] || []
            end
            (schema_data[:elements] || []).each do |elem|
              # Filter out self-references
              elem_name = elem[:name]
              elem[:used_by] = (used_by[elem_name] || []).reject do |ref|
                ref[:name] == elem_name
              end
            end
            (schema_data[:groups] || []).each do |group|
              group[:used_by] = used_by[group[:name]] || []
            end
            (schema_data[:attributes] || []).each do |attr|
              attr[:used_by] = used_by[attr[:name]] || []
            end
          end
        end

        # Build reverse index: type_name => [referencing component names]
        #
        # @param schemas_data [Array<Hash>] Serialized schema data
        # @return [Hash] Map of type_name => array of referencing component hashes
        def build_used_by_index(schemas_data)
          used_by = Hash.new { |h, k| h[k] = [] }

          schemas_data.each do |schema_data| # rubocop:disable Metrics/BlockLength
            schema_label = schema_data[:name] || "unknown"

            # Elements that reference a type
            (schema_data[:elements] || []).each do |elem|
              if elem[:name]
                used_by[elem[:name]] << { name: elem[:name],
                                          kind: "element",
                                          schema: schema_label }
              end

              # Elements used by (referenced by complex types)
              (schema_data[:complex_types] || []).each do |type|
                (type[:elements] || []).each do |type_el|
                  if type_el[:name] == "#{elem[:name]} (ref)"
                    used_by[elem[:name]] << { name: type[:name],
                                              kind: "complexType",
                                              schema: schema_label }
                  end
                end
              end
            end

            # Complex types: base type, element types, attribute types, groups
            (schema_data[:complex_types] || []).each do |type|
              if type[:base]
                used_by[type[:base]] << { name: type[:name],
                                          kind: "complexType",
                                          schema: schema_label }
              end
              (type[:elements] || []).each do |elem|
                element_name = elem[:name] || elem[:ref]
                if element_name
                  used_by[element_name] << { name: type[:name],
                                             kind: "complexType",
                                             schema: schema_label }
                end
                if elem[:type]
                  type_name = elem[:type].split(":").last || elem[:type]
                  used_by[type_name] << { name: type[:name],
                                          kind: "complexType",
                                          schema: schema_label }
                end
              end
              (type[:attributes] || []).each do |attr|
                if attr[:name]
                  used_by[attr[:name]] << { name: type[:name],
                                            kind: "complexType",
                                            schema: schema_label }
                end
              end
              (type[:attribute_groups] || []).each do |ag_ref|
                if ag_ref[:ref]
                  used_by[ag_ref[:ref]] << { name: type[:name],
                                             kind: "complexType",
                                             schema: schema_label }
                end
              end
              (type[:groups] || []).each do |grp_ref|
                if grp_ref[:ref]
                  used_by[grp_ref[:ref]] << { name: type[:name],
                                              kind: "complexType",
                                              schema: schema_label }
                end
              end
            end

            # Simple types: base type
            (schema_data[:simple_types] || []).each do |type|
              if type[:base]
                used_by[type[:base]] << { name: type[:name],
                                          kind: "simpleType",
                                          schema: schema_label }
              end
            end

            # Schema elements: type attribute
            (schema_data[:elements] || []).each do |elem|
              if elem[:type]
                type_name = elem[:type].split(":").last || elem[:type]
                used_by[type_name] << { name: elem[:name], kind: "element",
                                        schema: schema_label }
              end
            end
          end

          # Deduplicate
          used_by.each_key { |k| used_by[k] = used_by[k].uniq }
          used_by
        end

        # Serialize type attributes
        #
        # @param type [ComplexType] Complex type
        # @return [Array<Hash>] Serialized attributes
        def serialize_type_attributes(type)
          return [] unless type.attributes

          type.attributes.map do |attr|
            # Check for inline simpleType with enumeration
            enum_default, enum_type = extract_enumeration_default(attr)
            {
              name: attr.name || "#{attr.ref} (ref)",
              type: enum_type || attr.type,
              use: attr.use,
              default: enum_default || attr.default,
              fixed: attr.fixed,
              documentation: extract_documentation(attr),
            }
          end
        end

        # Serialize type elements
        #
        # @param type [ComplexType] Complex type
        # @return [Array<Hash>] Serialized elements
        def serialize_type_elements(type)
          return [] unless type.is_a?(Lutaml::Xml::Schema::Xsd::Sequence) ||
            type.is_a?(Lutaml::Xml::Schema::Xsd::Choice)

          type.element.map do |elem|
            {
              name: elem.name || "#{elem.ref} (ref)",
              type: elem.type,
              complex_type: serialize_complex_type(elem.complex_type, 0),
              min_occurs: elem.min_occurs,
              max_occurs: elem.max_occurs,
              occurs: {
                min: elem.min_occurs || 1,
                max: elem.max_occurs || 1,
              },
              reference: elem.ref,
              documentation: extract_documentation(elem),
            }
          end
        end

        # Serialize restriction
        #
        # @param type [SimpleType] Simple type
        # @return [Hash, nil] Restriction data
        def serialize_restriction(type)
          return nil unless type.restriction

          restriction = type.restriction
          return nil unless restriction

          {
            base: restriction.base,
            facets: serialize_facets(restriction),
          }
        end

        # Facet serializers: maps facet name to how to extract and format it
        #
        # Each entry: [method_name, facet_type_label]
        #   method_name  — the attribute method on RestrictionSimpleType
        #   facet_type   — the type string emitted in serialized facet
        FACET_METHODS = [
          [:enumeration, "enumeration"],
          [:pattern, "pattern"],
          [:min_length, "min_length"],
          [:max_length, "max_length"],
          [:length, "length"],
          [:min_inclusive, "min_inclusive"],
          [:max_inclusive, "max_inclusive"],
          [:min_exclusive, "min_exclusive"],
          [:max_exclusive, "max_exclusive"],
          [:total_digits, "total_digits"],
          [:fraction_digits, "fraction_digits"],
          [:white_space, "white_space"],
        ].freeze

        # Serialize facets
        #
        # @param restriction [Restriction] Restriction object
        # @return [Array<Hash>] Serialized facets
        def serialize_facets(restriction)
          return [] unless restriction

          FACET_METHODS.filter_map do |method_name, facet_type|
            value = restriction.public_send(method_name)
            next if value.nil? || value.empty?

            if method_name == :enumeration
              { type: facet_type, values: value }
            else
              { type: facet_type, value: value }
            end
          end
        end

        # Extract documentation from object
        #
        # @param obj [Object] Schema object
        # @return [String, nil] Documentation text
        def extract_documentation(obj)
          return nil unless obj.annotation
          return nil unless obj.annotation.documentations

          docs = obj.annotation.documentations
          return nil if docs.empty?

          docs.map(&:content).join("\n")
        end

        # Extract content model from complex type
        #
        # @param type [ComplexType] Complex type
        # @return [String] Content model type
        def extract_content_model(type)
          return "sequence" if type.sequence
          return "choice" if type.choice
          return "all" if type.all
          return "complex_content" if type.complex_content
          return "simple_content" if type.simple_content

          "empty"
        end

        # Extract base type from a content model's extension or restriction
        #
        # @param content_model [Object] simpleContent or complexContent
        # @return [String, nil] Base type name
        def base_from_content_model(content_model)
          if content_model.extension
            ext = content_model.extension
            return ext.base if ext.base
          elsif content_model.restriction
            rst = content_model.restriction
            return rst.base if rst.base
          end
          nil
        end

        # Extract base type from complex type
        #
        # @param type [ComplexType] Complex type
        # @return [String, nil] Base type name
        def extract_base_type(type)
          if type.complex_content
            base = base_from_content_model(type.complex_content)
            return base if base
          end

          if type.simple_content
            base = base_from_content_model(type.simple_content)
            return base if base
          end

          nil
        end

        # Extract base type from simple type
        #
        # @param type [SimpleType] Simple type
        # @return [String, nil] Base type name
        def extract_simple_base(type)
          return type.restriction.base if type.restriction&.base

          return type.list.item_type if type.list&.item_type

          if type.union
            return "union" # Union types have multiple bases
          end

          nil
        end

        # ID generation methods

        # Helper: Slugify for URL-safe IDs with CamelCase support
        #
        # @param name [String, nil] Name to slugify
        # @return [String] URL-safe slug
        def slugify(name)
          return "unnamed" unless name

          name.to_s
            .gsub(/([A-Z]+)([A-Z][a-z])/, '\1-\2') # Split acronyms: HTTPParser → HTTP-Parser
            .gsub(/([a-z\d])([A-Z])/, '\1-\2') # Split camelCase: fooBar → foo-Bar
            .downcase # Convert to lowercase
            .gsub(/[^a-z0-9]+/, "-") # Replace non-alphanumeric with dash
            .gsub(/^-|-$/, "") # Remove leading/trailing dashes
        end

        def schema_id(index, schema = nil, file_path = nil)
          # Use schema name instead of index
          name = schema_name(schema, file_path) if schema
          name ||= "schema-#{index}" # Fallback
          slugify(name)
        end

        def element_id(index, element = nil, prefix = nil)
          if element&.name
            slug = slugify(element.name)
            return prefix ? "element-#{prefix}-#{slug}" : "element-#{slug}"
          end

          "element-#{index}"
        end

        def complex_type_id(index, type = nil, prefix = nil)
          if type&.name
            slug = slugify(type.name)
            return prefix ? "type-#{prefix}-#{slug}" : "type-#{slug}"
          end

          "type-#{index}"
        end

        def simple_type_id(index, type = nil, prefix = nil)
          if type&.name
            slug = slugify(type.name)
            return prefix ? "simpletype-#{prefix}-#{slug}" : "simpletype-#{slug}"
          end

          "simpletype-#{index}"
        end

        def attribute_id(index, attr = nil, prefix = nil)
          if attr&.name
            slug = slugify(attr.name)
            return prefix ? "attr-#{prefix}-#{slug}" : "attr-#{slug}"
          end

          "attr-#{index}"
        end

        def group_id(index, group = nil, prefix = nil)
          if group&.name
            slug = slugify(group.name)
            return prefix ? "group-#{prefix}-#{slug}" : "group-#{slug}"
          end

          "group-#{index}"
        end

        # Helper methods

        def current_timestamp
          Time.now.utc.iso8601
        end

        def generator_info
          "lutaml-xsd v#{Lutaml::Xsd::VERSION}"
        end

        def default_title
          "XSD Schema Documentation"
        end

        def schema_name(schema, file_path = nil)
          # Prioritize filename if available and meaningful
          if file_path.is_a?(String) && !file_path.empty?
            basename = File.basename(file_path, ".*")
            # Use filename unless it's generic (schema, unnamed, or just numbers)
            return basename unless basename.match?(/^(schema|unnamed|\d+)$/i)
          end

          # Fallback to target namespace extraction
          if schema.target_namespace
            # Extract last meaningful part of namespace URI
            uri = schema.target_namespace
            # For URNs like "urn:oasis:names:tc:unitsml:schema:xsd:UnitsML-Schema-1.0"
            # extract the last part
            last_part = uri.split("/").last || uri.split(":").last || "unnamed"
            # Don't return if it's just a version number (e.g., "3.2")
            return last_part unless last_part.match?(/^\d+(\.\d+)*$/)
          end

          # Final fallback: use filename if we have one, even if generic
          if file_path.is_a?(String) && !file_path.empty?
            return File.basename(file_path,
                                 ".*")
          end

          "unnamed"
        end

        # Check if file path is an entrypoint
        #
        # @param file_path [String, nil] File path to check
        # @return [Boolean] True if file is an entrypoint
        def is_entrypoint?(file_path)
          return false unless file_path

          # Get original entrypoint files from package metadata
          # The metadata.files contains ONLY the original entry points,
          # not the resolved dependencies
          entrypoint_files = []

          if package
            metadata = package.metadata
            # Handle both Hash (backward compat) and SchemaRepositoryMetadata object
            entrypoint_files = if metadata.is_a?(Hash)
                                 metadata[:files] || metadata["files"] || []
                               elsif metadata
                                 metadata.files || []
                               else
                                 []
                               end
          end

          return false if entrypoint_files.empty?

          # Compare just the filename (basename) since paths may differ
          # between metadata (original paths) and serialized schemas (temp paths)
          file_basename = File.basename(file_path).downcase
          entrypoint_files.any? do |entry_path|
            File.basename(entry_path.to_s).downcase == file_basename
          end
        end

        # Clean file path to show relative path within package
        #
        # @param file_path [String, nil] Full file path
        # @return [String, nil] Cleaned path
        def clean_file_path(file_path)
          return nil unless file_path

          # Extract path relative to package (strip temp directory)
          # Transform: /var/folders/.../T/package.../schemas/file.xsd
          # To: schemas/file.xsd
          if file_path.include?("/schemas/")
            parts = file_path.split("/schemas/")
            "schemas/#{parts.last}"
          else
            File.basename(file_path)
          end
        end

        # Get schemas from repository
        #
        # @return [Hash] Hash of file_path => schema
        def get_schemas
          repository.all_schemas
        end

        # Index building methods (can be overridden)

        def build_id_index
          {}
        end

        def build_name_index
          {}
        end

        def build_type_index
          {}
        end

        # Generate XML instance representation for a component
        #
        # @param component [Element, ComplexType, SimpleType] Component to generate instance for
        # @return [String, nil] XML instance representation
        def generate_instance_xml(component)
          return nil unless component

          # Get the schema that contains this component
          schema = find_schema_for_component(component)
          return nil unless schema

          generator = XmlInstanceGenerator.new(
            schema,
            component,
            repository,
            all_schemas: get_schemas,
          )
          generator.generate
        rescue StandardError => e
          # Fallback if generation fails - return nil to skip display
          warn "Failed to generate instance XML: #{e.message}" if config[:verbose]
          nil
        end

        # Find the schema that contains a given component
        #
        # @param component [Object] Component to find schema for
        # @return [Schema, nil] Schema containing the component
        def find_schema_for_component(component)
          # Search through all schemas to find the one containing this component
          get_schemas.each_value do |schema|
            # Check if component is in this schema's elements
            return schema if schema.element&.include?(component)

            # Check if component is in this schema's complex types
            return schema if schema.complex_type&.include?(component)

            # Check if component is in this schema's simple types
            return schema if schema.simple_type&.include?(component)
          end

          # If not found, return first schema as fallback
          _path, schema = get_schemas.first
          schema
        end

        # Generate SVG diagram for a component using xsdvi Ruby API
        #
        # @param component_data [Hash] Serialized component data
        # @param component_type [Symbol] Component type (:element or :type)
        # @param file_path [String, nil] XSD file path for xsdvi
        # @return [String, nil] SVG diagram markup
        def generate_diagram(component_data, component_type, file_path = nil)
          name = component_data[:name] || component_data["name"]
          return nil unless name && file_path

          gen_element_diagram(name, file_path, component_type)
        rescue StandardError => e
          warn "Warning: Failed to generate SVG diagram: #{e.message}" if ENV["DEBUG"]
          nil
        end
      end
    end
  end
end
