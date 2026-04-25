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
        if single
          collection.each_with_object({}) do |item, hash|
            key = item.send(method)
            hash[key] = item if key
          end
        else
          collection.each_with_object({}) do |item, hash|
            key = item.send(method)
            (hash[key] ||= []) << item if key
          end
        end
      end

      # Eagerly build all lazy lookup indexes before freezing
      def build_lookup_indexes
        @objects_by_guid = build_group_index(objects, :ea_guid, single: true)
        @attributes_by_object_id = build_group_index(attributes, :ea_object_id)
        @operations_by_object_id = build_group_index(operations, :ea_object_id)
        @operation_params_by_id = build_group_index(operation_params,
                                                    :operationid)
        @connectors_by_start = build_group_index(connectors, :start_object_id)
        @connectors_by_end = build_group_index(connectors, :end_object_id)
        @packages_by_parent = build_group_index(packages, :parent_id)
        @objects_by_package_id = build_group_index(objects, :package_id)
        @diagrams_by_package_id = build_group_index(diagrams, :package_id)
        @diagram_objects_by_id = build_group_index(diagram_objects, :diagram_id)
        @diagram_links_by_id = build_group_index(diagram_links, :diagramid)
        # Also build hash indexes for find_* methods
        @packages_by_id = build_group_index(packages, :package_id, single: true)
        @connectors_by_id = build_group_index(connectors, :connector_id,
                                              single: true)
        @diagrams_by_id = build_group_index(diagrams, :diagram_id, single: true)
        @attributes_by_id = build_group_index(attributes, :id, single: true)
      end
    end
  end
end
