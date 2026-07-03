# frozen_string_literal: true

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

      COLLECTION_ACCESSORS = %i[
        attributes operations operation_params connectors packages
        diagrams diagram_objects diagram_links object_constraints
        tagged_values object_properties attribute_tags xrefs
        stereotypes datatypes constraint_types connector_types
        diagram_types object_types status_types complexity_types
        documents scripts
      ].freeze

      COLLECTION_ACCESSORS.each do |name|
        define_method(name) do
          @collections[name] || []
        end
      end

      # Get objects collection (special: wrapped in ObjectRepository)
      #
      # @return [Repositories::ObjectRepository] Repository for objects
      def objects
        return @objects if defined?(@objects)

        @objects = Repositories::ObjectRepository.new(
          @collections[:objects] || [],
        )
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

      def find_package(id)
        ensure_lookup_indexes
        @packages_by_id[id]
      end

      def find_attribute(id)
        ensure_lookup_indexes
        @attributes_by_id[id]
      end

      def find_connector(id)
        ensure_lookup_indexes
        @connectors_by_id[id]
      end

      def find_diagram(id)
        ensure_lookup_indexes
        @diagrams_by_id[id]
      end

      def attributes_for_object(id)
        ensure_lookup_indexes
        @attributes_by_object_id[id] || []
      end

      def operations_for_object(id)
        ensure_lookup_indexes
        @operations_by_object_id[id] || []
      end

      def operation_params_for(id)
        ensure_lookup_indexes
        @operation_params_by_id[id] || []
      end

      def child_packages_for(id)
        ensure_lookup_indexes
        @packages_by_parent[id] || []
      end

      def objects_in_package(id)
        ensure_lookup_indexes
        @objects_by_package_id[id] || []
      end

      def diagrams_in_package(id)
        ensure_lookup_indexes
        @diagrams_by_package_id[id] || []
      end

      def diagram_objects_for(id)
        ensure_lookup_indexes
        @diagram_objects_by_id[id] || []
      end

      def diagram_links_for(id)
        ensure_lookup_indexes
        @diagram_links_by_id[id] || []
      end

      # Find an object by ID
      def find_object(id)
        objects.find_by_key(:ea_object_id, id)
      end

      # Find object by ea_guid
      def find_object_by_guid(ea_guid)
        ensure_lookup_indexes
        @objects_by_guid[ea_guid]
      end

      # Get connectors involving a specific object (start or end)
      def connectors_for_object(object_id)
        ensure_lookup_indexes
        (@connectors_by_start[object_id] || []) +
          (@connectors_by_end[object_id] || [])
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
        objects
        ensure_lookup_indexes
        @collections.freeze
        super
      end

      private

      def ensure_lookup_indexes
        return if @lookup_indexes_built

        build_lookup_indexes
        @lookup_indexes_built = true
      end

      def build_group_index(collection, method, single: false)
        collection.each_with_object({}) do |item, hash|
          key = item.public_send(method)
          next unless key

          single ? (hash[key] = item) : ((hash[key] ||= []) << item)
        end
      end

      def build_lookup_indexes
        build_primary_indexes
        build_secondary_indexes
      end

      def build_primary_indexes
        build_object_indexes
        build_feature_indexes
        build_connector_indexes
        build_diagram_indexes
      end

      def build_object_indexes
        @objects_by_guid = build_group_index(objects, :ea_guid, single: true)
        @objects_by_package_id = build_group_index(objects, :package_id)
        @packages_by_parent = build_group_index(packages, :parent_id)
      end

      def build_feature_indexes
        @attributes_by_object_id = build_group_index(attributes, :ea_object_id)
        @operations_by_object_id = build_group_index(operations, :ea_object_id)
        @operation_params_by_id = build_group_index(operation_params,
                                                    :operationid)
      end

      def build_connector_indexes
        @connectors_by_start = build_group_index(connectors, :start_object_id)
        @connectors_by_end = build_group_index(connectors, :end_object_id)
      end

      def build_diagram_indexes
        @diagrams_by_package_id = build_group_index(diagrams, :package_id)
        @diagram_objects_by_id = build_group_index(diagram_objects, :diagram_id)
        @diagram_links_by_id = build_group_index(diagram_links, :diagramid)
      end

      def build_secondary_indexes
        @packages_by_id = build_group_index(packages, :package_id, single: true)
        @connectors_by_id = build_group_index(connectors, :connector_id,
                                              single: true)
        @diagrams_by_id = build_group_index(diagrams, :diagram_id, single: true)
        @attributes_by_id = build_group_index(attributes, :id, single: true)
      end
    end
  end
end
