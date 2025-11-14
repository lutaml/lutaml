# frozen_string_literal: true

require_relative "repositories/object_repository"

module Lutaml
  module Qea
    # Database container for all loaded EA models
    #
    # This class provides a unified container for all EA table collections
    # loaded from a QEA database. It stores collections by name and provides
    # accessor methods, statistics, and lookup functionality.
    #
    # @example Load and access database
    #   database = Lutaml::Qea::Services::DatabaseLoader.new("file.qea").load
    #   puts database.stats
    #   # => {"objects" => 693, "attributes" => 1910, ...}
    #
    #   classes = database.objects.find_by_type("Class")
    #   obj = database.find_object(123)
    class Database
      # @return [Hash<Symbol, Array>] Collections of records by name
      attr_reader :collections

      # @return [String] Path to the QEA file
      attr_reader :qea_path

      # @return [SQLite3::Database, nil] Database connection
      attr_reader :connection

      def initialize(qea_path, connection = nil)
        @qea_path = qea_path
        @connection = connection
        @collections = {}
        @mutex = Mutex.new
      end

      # Set database connection
      #
      # @param connection [SQLite3::Database] Database connection
      # @return [void]
      def connection=(connection)
        @connection = connection
      end

      # Add a collection to the database
      #
      # @param name [Symbol, String] Collection name (e.g., :objects)
      # @param records [Array] Array of model instances
      # @return [void]
      def add_collection(name, records)
        @mutex.synchronize do
          @collections[name.to_sym] = records.freeze
        end
      end

      # Get objects collection
      #
      # @return [Repositories::ObjectRepository] Repository for objects
      def objects
        return @objects if defined?(@objects)

        @objects = Repositories::ObjectRepository.new(
          @collections[:objects] || [],
        )
      end

      # Get attributes collection
      #
      # @return [Array<Models::EaAttribute>] Array of attributes
      def attributes
        @collections[:attributes] || []
      end

      # Get operations collection
      #
      # @return [Array<Models::EaOperation>] Array of operations
      def operations
        @collections[:operations] || []
      end

      # Get operation parameters collection
      #
      # @return [Array<Models::EaOperationParam>] Array of operation parameters
      def operation_params
        @collections[:operation_params] || []
      end

      # Get connectors collection
      #
      # @return [Array<Models::EaConnector>] Array of connectors
      def connectors
        @collections[:connectors] || []
      end

      # Get packages collection
      #
      # @return [Array<Models::EaPackage>] Array of packages
      def packages
        @collections[:packages] || []
      end

      # Get diagrams collection
      #
      # @return [Array<Models::EaDiagram>] Array of diagrams
      def diagrams
        @collections[:diagrams] || []
      end

      # Get diagram objects collection (visual placement)
      #
      # @return [Array<Models::EaDiagramObject>] Array of diagram objects
      def diagram_objects
        @collections[:diagram_objects] || []
      end

      # Get diagram links collection (visual routing)
      #
      # @return [Array<Models::EaDiagramLink>] Array of diagram links
      def diagram_links
        @collections[:diagram_links] || []
      end

      # Get object constraints collection
      #
      # @return [Array<Models::EaObjectConstraint>] Array of object
      #   constraints
      def object_constraints
        @collections[:object_constraints] || []
      end

      # Get tagged values collection
      #
      # @return [Array<Models::EaTaggedValue>] Array of tagged values
      def tagged_values
        @collections[:tagged_values] || []
      end

      # Get object properties collection
      #
      # @return [Array<Models::EaObjectProperty>] Array of object properties
      def object_properties
        @collections[:object_properties] || []
      end

      # Get attribute tags collection
      #
      # @return [Array<Models::EaAttributeTag>] Array of attribute tags
      def attribute_tags
        @collections[:attribute_tags] || []
      end

      # Get cross-references collection
      #
      # @return [Array<Models::EaXref>] Array of cross-references
      def xrefs
        @collections[:xrefs] || []
      end

      # Get stereotypes collection
      #
      # @return [Array<Models::EaStereotype>] Array of stereotype definitions
      def stereotypes
        @collections[:stereotypes] || []
      end

      # Get datatypes collection
      #
      # @return [Array<Models::EaDatatype>] Array of datatype definitions
      def datatypes
        @collections[:datatypes] || []
      end

      # Get constraint types collection (Priority 3 lookup table)
      #
      # @return [Array<Models::EaConstraintType>] Array of constraint type
      #   definitions
      def constraint_types
        @collections[:constraint_types] || []
      end

      # Get connector types collection (Priority 3 lookup table)
      #
      # @return [Array<Models::EaConnectorType>] Array of connector type
      #   definitions
      def connector_types
        @collections[:connector_types] || []
      end

      # Get diagram types collection (Priority 3 lookup table)
      #
      # @return [Array<Models::EaDiagramType>] Array of diagram type
      #   definitions
      def diagram_types
        @collections[:diagram_types] || []
      end

      # Get object types collection (Priority 3 lookup table)
      #
      # @return [Array<Models::EaObjectType>] Array of object type definitions
      def object_types
        @collections[:object_types] || []
      end

      # Get status types collection (Priority 3 lookup table)
      #
      # @return [Array<Models::EaStatusType>] Array of status type definitions
      def status_types
        @collections[:status_types] || []
      end

      # Get complexity types collection (Priority 3 lookup table)
      #
      # @return [Array<Models::EaComplexityType>] Array of complexity type
      #   definitions
      def complexity_types
        @collections[:complexity_types] || []
      end

      # Get statistics for all collections
      #
      # @return [Hash<String, Integer>] Record counts by collection name
      #
      # @example
      #   database.stats
      #   # => {
      #   #   "objects" => 693,
      #   #   "attributes" => 1910,
      #   #   "connectors" => 908,
      #   #   ...
      #   # }
      def stats
        @collections.each_with_object({}) do |(name, records), hash|
          hash[name.to_s] = records.size
        end
      end

      # Get total number of records across all collections
      #
      # @return [Integer] Total record count
      def total_records
        @collections.values.sum(&:size)
      end

      # Find an object by ID
      #
      # @param id [Integer] Object ID
      # @return [Models::EaObject, nil] The object or nil if not found
      def find_object(id)
        objects.find(id)
      end

      # Find a package by ID
      #
      # @param id [Integer] Package ID
      # @return [Models::EaPackage, nil] The package or nil if not found
      def find_package(id)
        packages.find { |pkg| pkg.package_id == id }
      end

      # Find an attribute by ID
      #
      # @param id [Integer] Attribute ID
      # @return [Models::EaAttribute, nil] The attribute or nil if not found
      def find_attribute(id)
        attributes.find { |attr| attr.id == id }
      end

      # Find a connector by ID
      #
      # @param id [Integer] Connector ID
      # @return [Models::EaConnector, nil] The connector or nil if not found
      def find_connector(id)
        connectors.find { |conn| conn.connector_id == id }
      end

      # Find a diagram by ID
      #
      # @param id [Integer] Diagram ID
      # @return [Models::EaDiagram, nil] The diagram or nil if not found
      def find_diagram(id)
        diagrams.find { |diag| diag.diagram_id == id }
      end

      # Check if database is empty
      #
      # @return [Boolean] true if no collections loaded
      def empty?
        @collections.empty? || total_records.zero?
      end

      # Get collection names
      #
      # @return [Array<Symbol>] Array of collection names
      def collection_names
        @collections.keys
      end

      # Freeze all collections to make database immutable
      #
      # @return [self]
      def freeze
        # Memoize repositories before freezing
        objects

        @collections.freeze
        super
      end
    end
  end
end
