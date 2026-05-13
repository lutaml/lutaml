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

      SINGLE_INDEXES = {
        find_package: [:packages, :package_id],
        find_attribute: [:attributes, :id],
        find_connector: [:connectors, :connector_id],
        find_diagram: [:diagrams, :diagram_id],
      }.freeze

      GROUP_INDEXES = {
        attributes_for_object: [:attributes, :ea_object_id],
        operations_for_object: [:operations, :ea_object_id],
        operation_params_for: [:operation_params, :operationid],
        child_packages_for: [:packages, :parent_id],
        objects_in_package: [:objects, :package_id],
        diagrams_in_package: [:diagrams, :package_id],
        diagram_objects_for: [:diagram_objects, :diagram_id],
        diagram_links_for: [:diagram_links, :diagramid],
      }.freeze

      SINGLE_INDEXES.each do |method_name, (collection, field)|
        ivar = :"@#{method_name}_idx"
        define_method(method_name) do |id|
          idx = instance_variable_get(ivar)
          unless idx
            idx = build_group_index(public_send(collection), field, single: true)
            instance_variable_set(ivar, idx)
          end
          idx[id]
        end
      end

      GROUP_INDEXES.each do |method_name, (collection, field)|
        ivar = :"@#{method_name}_idx"
        define_method(method_name) do |id|
          idx = instance_variable_get(ivar)
          unless idx
            idx = build_group_index(public_send(collection), field)
            instance_variable_set(ivar, idx)
          end
          idx[id] || []
        end
      end

      # Find an object by ID
      #
      # @param id [Integer] Object ID
      # @return [Models::EaObject, nil] The object or nil if not found
      def find_object(id)
        objects.find_by_key(:ea_object_id, id)
      end

      # Find object by ea_guid
      #
      # @param ea_guid [String] Object GUID
      # @return [Models::EaObject, nil] The object or nil if not found
      def find_object_by_guid(ea_guid)
        @objects_by_guid ||= build_group_index(objects, :ea_guid, single: true)
        @objects_by_guid[ea_guid]
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

        # Eagerly build all lookup indexes before freezing
        build_lookup_indexes

        @collections.freeze
        super
      end
    end
  end
end
