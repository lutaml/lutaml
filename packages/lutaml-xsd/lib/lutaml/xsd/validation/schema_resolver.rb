# frozen_string_literal: true

require_relative "schema_location_extractor"

module Lutaml
  module Xsd
    module Validation
      # SchemaResolver resolves XSD schemas from locations
      #
      # This class takes schema location hints from XML documents and
      # resolves them to actual XSD schema objects using the SchemaRepository.
      #
      # @example Resolve schemas from XML document
      #   resolver = SchemaResolver.new(repository)
      #   schemas = resolver.resolve_from_document(xml_document)
      #
      # @example Resolve schemas from locations
      #   locations = { "http://example.com" => "schema.xsd" }
      #   schemas = resolver.resolve_from_locations(locations)
      class SchemaResolver
        # @return [SchemaRepository] The schema repository
        attr_reader :repository

        # Initialize a new SchemaResolver
        #
        # @param repository [SchemaRepository] The schema repository to use
        def initialize(repository)
          @repository = repository
        end

        # Resolve schemas from an XML document
        #
        # Extracts schema locations from the document and resolves them
        # to schema objects.
        #
        # @param document [XmlDocument] The XML document
        # @return [Hash] Hash with resolved schemas
        #
        # @example
        #   result = resolver.resolve_from_document(doc)
        #   # => {
        #   #   schemas: [schema1, schema2],
        #   #   unresolved: ["missing.xsd"]
        #   # }
        def resolve_from_document(document)
          extractor = SchemaLocationExtractor.new(document)
          locations = extractor.extract_schema_locations
          no_ns_location = extractor.extract_no_namespace_schema_location

          resolve_all_locations(locations, no_ns_location)
        end

        # Resolve schemas from explicit locations
        #
        # @param locations [Hash<String, String>] Map of namespace to location
        # @param no_namespace_location [String, nil] No-namespace schema location
        # @return [Hash] Hash with resolved schemas
        def resolve_from_locations(locations, no_namespace_location = nil)
          resolve_all_locations(locations, no_namespace_location)
        end

        # Resolve a single schema by namespace
        #
        # @param namespace [String] The target namespace
        # @return [Schema, nil] The resolved schema or nil
        def resolve_by_namespace(namespace)
          @repository.schemas.find do |schema|
            schema.target_namespace == namespace
          end
        end

        # Resolve a single schema by location
        #
        # @param location [String] The schema location
        # @return [Schema, nil] The resolved schema or nil
        def resolve_by_location(_location)
          # This is a simplified implementation
          # In a real implementation, this would:
          # 1. Check if location is in repository
          # 2. Try to load from file system
          # 3. Try to download if URL
          # 4. Parse and add to repository
          nil
        end

        # Check if all schemas for a document can be resolved
        #
        # @param document [XmlDocument] The XML document
        # @return [Boolean]
        def can_resolve_all?(document)
          result = resolve_from_document(document)
          result[:unresolved].empty?
        end

        # Get missing schema locations for a document
        #
        # @param document [XmlDocument] The XML document
        # @return [Array<String>] List of unresolved locations
        def missing_schemas(document)
          result = resolve_from_document(document)
          result[:unresolved]
        end

        private

        # Resolve all schema locations
        #
        # @param locations [Hash<String, String>] Namespaced locations
        # @param no_ns_location [String, nil] No-namespace location
        # @return [Hash] Resolution result
        def resolve_all_locations(locations, no_ns_location)
          schemas = []
          unresolved = []

          # Resolve namespaced schemas
          locations.each do |namespace, location|
            schema = resolve_by_namespace(namespace)
            if schema
              schemas << schema
            else
              unresolved << location
            end
          end

          # Resolve no-namespace schema
          if no_ns_location
            # Try to resolve from repository
            # For now, mark as unresolved
            unresolved << no_ns_location
          end

          {
            schemas: schemas,
            unresolved: unresolved,
            namespaces: locations.keys,
          }
        end
      end
    end
  end
end
