# frozen_string_literal: true

module Lutaml
  module Qea
    class Database
      private

      # Build a group index from a collection by a given attribute.
      # BaseRepository overrides group_by to take a symbol (not a block),
      # so we use each_with_object instead.
      #
      # @param collection [Array] Collection to index
      # @param method [Symbol] Attribute method to group by
      # @param single [Boolean] If true, return single object (last match)
      #   instead of array
      # @return [Hash] Group index
      def build_group_index(collection, method, single: false)
        collection.each_with_object({}) do |item, hash|
          key = item.public_send(method)
          next unless key

          single ? (hash[key] = item) : ((hash[key] ||= []) << item)
        end
      end

      # Eagerly build all lazy lookup indexes before freezing
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
