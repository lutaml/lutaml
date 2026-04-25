# frozen_string_literal: true

require_relative "repositories/object_repository"
require_relative "lookup_indexes"

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

      # Get documents collection (Priority 4)
      #
      # @return [Array<Models::EaDocument>] Array of document artifacts
      def documents
        @collections[:documents] || []
      end

      # Get scripts collection (Priority 4)
      #
      # @return [Array<Models::EaScript>] Array of behavioral scripts
      def scripts
        @collections[:scripts] || []
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
        objects.find_by_key(:ea_object_id, id)
      end

      # Find a package by ID
      #
      # @param id [Integer] Package ID
      # @return [Models::EaPackage, nil] The package or nil if not found
      def find_package(id)
        @packages_by_id ||= build_group_index(packages, :package_id,
                                              single: true)
        @packages_by_id[id]
      end

      # Find an attribute by ID
      #
      # @param id [Integer] Attribute ID
      # @return [Models::EaAttribute, nil] The attribute or nil if not found
      def find_attribute(id)
        @attributes_by_id ||= build_group_index(attributes, :id, single: true)
        @attributes_by_id[id]
      end

      # Find a connector by ID
      #
      # @param id [Integer] Connector ID
      # @return [Models::EaConnector, nil] The connector or nil if not found
      def find_connector(id)
        @connectors_by_id ||= build_group_index(connectors, :connector_id,
                                                single: true)
        @connectors_by_id[id]
      end

      # Find a diagram by ID
      #
      # @param id [Integer] Diagram ID
      # @return [Models::EaDiagram, nil] The diagram or nil if not found
      def find_diagram(id)
        @diagrams_by_id ||= build_group_index(diagrams, :diagram_id,
                                              single: true)
        @diagrams_by_id[id]
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

      # Find object by ea_guid
      #
      # @param ea_guid [String] Object GUID
      # @return [Models::EaObject, nil] The object or nil if not found
      def find_object_by_guid(ea_guid)
        @objects_by_guid ||= build_group_index(objects, :ea_guid, single: true)
        @objects_by_guid[ea_guid]
      end

      # Get attributes for a specific object
      #
      # @param object_id [Integer] Object ID
      # @return [Array<Models::EaAttribute>] Attributes for the object
      def attributes_for_object(object_id)
        @attributes_by_object_id ||= build_group_index(attributes,
                                                       :ea_object_id)
        @attributes_by_object_id[object_id] || []
      end

      # Get operations for a specific object
      #
      # @param object_id [Integer] Object ID
      # @return [Array<Models::EaOperation>] Operations for the object
      def operations_for_object(object_id)
        @operations_by_object_id ||= build_group_index(operations,
                                                       :ea_object_id)
        @operations_by_object_id[object_id] || []
      end

      # Get operation parameters for a specific operation
      #
      # @param operation_id [Integer] Operation ID
      # @return [Array<Models::EaOperationParam>] Parameters for the operation
      def operation_params_for(operation_id)
        @operation_params_by_id ||= build_group_index(operation_params,
                                                      :operationid)
        @operation_params_by_id[operation_id] || []
      end

      # Get connectors involving a specific object (start or end)
      #
      # @param object_id [Integer] Object ID
      # @return [Array<Models::EaConnector>] Connectors for the object
      def connectors_for_object(object_id)
        @connectors_by_start ||= build_group_index(connectors, :start_object_id)
        @connectors_by_end ||= build_group_index(connectors, :end_object_id)
        (@connectors_by_start[object_id] || []) +
          (@connectors_by_end[object_id] || [])
      end

      # Get child packages for a parent
      #
      # @param parent_id [Integer] Parent package ID
      # @return [Array<Models::EaPackage>] Child packages
      def child_packages_for(parent_id)
        @packages_by_parent ||= build_group_index(packages, :parent_id)
        @packages_by_parent[parent_id] || []
      end

      # Get objects in a specific package
      #
      # @param package_id [Integer] Package ID
      # @return [Array<Models::EaObject>] Objects in the package
      def objects_in_package(package_id)
        @objects_by_package_id ||= build_group_index(objects, :package_id)
        @objects_by_package_id[package_id] || []
      end

      # Get diagrams in a specific package
      #
      # @param package_id [Integer] Package ID
      # @return [Array<Models::EaDiagram>] Diagrams in the package
      def diagrams_in_package(package_id)
        @diagrams_by_package_id ||= build_group_index(diagrams, :package_id)
        @diagrams_by_package_id[package_id] || []
      end

      # Get diagram objects for a specific diagram
      #
      # @param diagram_id [Integer] Diagram ID
      # @return [Array<Models::EaDiagramObject>] Diagram objects
      def diagram_objects_for(diagram_id)
        @diagram_objects_by_id ||= build_group_index(diagram_objects,
                                                     :diagram_id)
        @diagram_objects_by_id[diagram_id] || []
      end

      # Get diagram links for a specific diagram
      #
      # @param diagram_id [Integer] Diagram ID
      # @return [Array<Models::EaDiagramLink>] Diagram links
      def diagram_links_for(diagram_id)
        @diagram_links_by_id ||= build_group_index(diagram_links, :diagramid)
        @diagram_links_by_id[diagram_id] || []
      end

      # Freeze all collections to make database immutable
      #
      # @return [self]
      def freeze
        # Memoize repositories before freezing
        objects

        # Eagerly build all lookup indexes before freezing
        build_lookup_indexes

        @collections.freeze
        super
      end
    end
  end
end
