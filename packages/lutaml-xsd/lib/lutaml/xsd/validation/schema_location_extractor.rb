# frozen_string_literal: true

module Lutaml
  module Xsd
    module Validation
      # SchemaLocationExtractor extracts schema locations from XML documents
      #
      # This class extracts xsi:schemaLocation and xsi:noNamespaceSchemaLocation
      # attributes from XML documents to resolve which XSD schemas should be
      # used for validation.
      #
      # @example Extract schema locations
      #   extractor = SchemaLocationExtractor.new(xml_document)
      #   locations = extractor.extract_schema_locations
      #   # => { "http://example.com" => "schema.xsd" }
      #
      # @example Extract no-namespace schema location
      #   location = extractor.extract_no_namespace_schema_location
      #   # => "schema.xsd"
      class SchemaLocationExtractor
        # XML Schema instance namespace
        XSI_NAMESPACE = "http://www.w3.org/2001/XMLSchema-instance"

        # @return [XmlDocument] The XML document to extract from
        attr_reader :document

        # Initialize a new SchemaLocationExtractor
        #
        # @param document [XmlDocument] The XML document
        def initialize(document)
          @document = document
        end

        # Extract schema locations from xsi:schemaLocation attribute
        #
        # The xsi:schemaLocation attribute contains pairs of namespace URIs
        # and schema locations: "namespace1 location1 namespace2 location2"
        #
        # @return [Hash<String, String>] Map of namespace URI to schema location
        #
        # @example
        #   locations = extractor.extract_schema_locations
        #   # => {
        #   #   "http://example.com" => "schema.xsd",
        #   #   "http://other.com" => "other.xsd"
        #   # }
        def extract_schema_locations
          root = @document.root_element
          return {} unless root

          schema_location_attr = root.attribute(
            "schemaLocation",
            namespace: XSI_NAMESPACE,
          )

          return {} unless schema_location_attr

          parse_schema_location_pairs(schema_location_attr.value)
        end

        # Extract no-namespace schema location
        #
        # The xsi:noNamespaceSchemaLocation attribute contains a single
        # schema location for elements without a namespace.
        #
        # @return [String, nil] Schema location or nil if not present
        #
        # @example
        #   location = extractor.extract_no_namespace_schema_location
        #   # => "schema.xsd"
        def extract_no_namespace_schema_location
          root = @document.root_element
          return nil unless root

          no_ns_attr = root.attribute(
            "noNamespaceSchemaLocation",
            namespace: XSI_NAMESPACE,
          )

          no_ns_attr&.value
        end

        # Extract all schema locations (both namespaced and non-namespaced)
        #
        # @return [Hash] Hash with :namespaced and :no_namespace keys
        #
        # @example
        #   all_locations = extractor.extract_all
        #   # => {
        #   #   namespaced: { "http://example.com" => "schema.xsd" },
        #   #   no_namespace: "schema.xsd"
        #   # }
        def extract_all
          {
            namespaced: extract_schema_locations,
            no_namespace: extract_no_namespace_schema_location,
          }.compact
        end

        # Check if document has schema location hints
        #
        # @return [Boolean]
        def has_schema_locations?
          !extract_schema_locations.empty? ||
            !extract_no_namespace_schema_location.nil?
        end

        # Get all schema location URIs (for downloading/resolving)
        #
        # @return [Array<String>] List of all schema location URIs
        def all_schema_uris
          uris = extract_schema_locations.values
          no_ns = extract_no_namespace_schema_location
          uris << no_ns if no_ns
          uris
        end

        # Convert to hash representation
        #
        # @return [Hash]
        def to_h
          {
            schema_locations: extract_schema_locations,
            no_namespace_location: extract_no_namespace_schema_location,
            has_locations: has_schema_locations?,
          }.compact
        end

        private

        # Parse schema location pairs from attribute value
        #
        # Format: "namespace1 location1 namespace2 location2"
        #
        # @param value [String] The attribute value
        # @return [Hash<String, String>] Parsed namespace to location map
        def parse_schema_location_pairs(value)
          return {} if value.nil? || value.empty?

          pairs = value.split
          result = {}

          # Process pairs (namespace, location)
          pairs.each_slice(2) do |namespace, location|
            next unless namespace && location

            result[namespace] = location
          end

          result
        end
      end
    end
  end
end
