# frozen_string_literal: true

module Lutaml
  module Xsd
    class SchemaRepository
      # Internal helper for indexing and looking up type definitions
      # across multiple schemas
      class TypeIndex
        def initialize
          @index = {}
          @schema_files = {}
        end

        # Build index from parsed schemas
        # @param schemas [Hash] Hash of schema_file => Schema object
        def build_from_schemas(schemas)
          schemas.each do |file_path, schema|
            index_schema(schema, file_path)
          end
        end

        # Index a single schema
        # @param schema [Schema] The schema to index
        # @param file_path [String] Path to the schema file
        def index_schema(schema, file_path)
          return unless schema

          namespace = schema.target_namespace

          # Index simple types
          index_collection(schema.simple_type, namespace, file_path,
                           :simple_type)

          # Index complex types
          index_collection(schema.complex_type, namespace, file_path,
                           :complex_type)

          # Index top-level elements
          index_collection(schema.element, namespace, file_path, :element)

          # Index attribute groups
          index_collection(schema.attribute_group, namespace, file_path,
                           :attribute_group)

          # Index groups
          index_collection(schema.group, namespace, file_path, :group)

          # Index top-level attributes
          index_collection(schema.attribute, namespace, file_path, :attribute)

          # Index inline/anonymous complex types from elements
          index_inline_complex_types(schema, namespace, file_path)

          # NOTE: imported and included schemas are already parsed and available
          # in the processed_schemas cache. We'll index them when build_from_schemas
          # iterates over all schemas in the cache.
        end

        # Index inline/anonymous complex types defined within elements
        # @param schema [Schema] The schema to index
        # @param namespace [String] The namespace URI
        # @param file_path [String] Path to the schema file
        def index_inline_complex_types(schema, namespace, file_path)
          return unless schema.element

          elements = schema.element.is_a?(Array) ? schema.element : [schema.element]
          elements.compact.each do |element|
            next unless element.complex_type

            inline_ct = element.complex_type
            # Only index if it doesn't already have a name (truly anonymous)
            next if inline_ct.name

            # Generate a synthetic name based on the element name
            inline_name = "#{element.name}_type"
            clark_key = build_clark_key(namespace, inline_name)
            @index[clark_key] = {
              type: :complex_type,
              definition: inline_ct,
              namespace: namespace,
              schema_file: file_path,
              inline_of_element: element.name,
            }
            @schema_files[file_path] ||= true
          end
        end

        # Find a type by Clark notation key
        # @param clark_key [String] The Clark notation key (e.g., "{namespace}LocalName")
        # @return [Hash, nil] Type information or nil if not found
        def find(clark_key)
          @index[clark_key]
        end

        # Find a type by namespace and local name
        # @param namespace [String] The namespace URI
        # @param local_name [String] The local type name
        # @return [Hash, nil] Type information or nil if not found
        def find_by_namespace_and_name(namespace, local_name)
          return nil if local_name.nil?

          clark_key = build_clark_key(namespace, local_name)
          find(clark_key)
        end

        # Get all types in a namespace
        # @param namespace [String] The namespace URI
        # @return [Array<Hash>] List of type information hashes
        def find_all_in_namespace(namespace)
          @index.select { |key, _| key.start_with?("{#{namespace}}") }.values
        end

        # Get suggestions for similar type names (for error messages)
        # @param namespace [String] The namespace URI
        # @param local_name [String] The local type name
        # @param limit [Integer] Maximum number of suggestions
        # @return [Array<String>] List of suggested type names
        def suggest_similar(namespace, local_name, limit: 5)
          types_in_namespace = find_all_in_namespace(namespace)
          return [] if types_in_namespace.empty?

          # Simple similarity: check if name is contained or contains the search term
          similar = types_in_namespace.select do |type_info|
            name = type_info[:definition]&.name
            next false unless name

            name.downcase.include?(local_name.downcase) ||
              local_name.downcase.include?(name.downcase)
          end

          similar.filter_map { |info| info[:definition]&.name }.take(limit)
        end

        # Get all indexed types
        # @return [Hash] The complete index
        def all
          @index.dup
        end

        # Get statistics about indexed types
        # @return [Hash] Statistics
        def statistics
          type_counts = Hash.new(0)
          @index.each_value do |info|
            type_counts[info[:type]] += 1
          end

          {
            total_types: @index.size,
            by_type: type_counts,
            namespaces: namespace_count,
          }
        end

        # Clear the index
        def clear
          @index.clear
          @schema_files.clear
        end

        private

        # Index a collection of type definitions
        # @param collection [Array] Collection of type definitions
        # @param namespace [String] The namespace URI
        # @param file_path [String] Source file path
        # @param type_symbol [Symbol] Type identifier (:simple_type, :complex_type, etc.)
        def index_collection(collection, namespace, file_path, type_symbol)
          return unless collection && !collection.empty?

          collection.each do |item|
            next unless item&.name

            clark_key = build_clark_key(namespace, item.name)
            @index[clark_key] = {
              type: type_symbol,
              definition: item,
              namespace: namespace,
              schema_file: file_path,
            }
            @schema_files[file_path] ||= true
          end
        end

        # Build Clark notation key
        # @param namespace [String, nil] The namespace URI
        # @param local_name [String] The local name
        # @return [String] Clark notation key
        def build_clark_key(namespace, local_name)
          if namespace && !namespace.empty?
            "{#{namespace}}#{local_name}"
          else
            local_name
          end
        end

        # Count unique namespaces
        # @return [Integer]
        def namespace_count
          @index.values.filter_map { |info| info[:namespace] }.uniq.size
        end
      end
    end
  end
end
