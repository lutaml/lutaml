# frozen_string_literal: true

module Lutaml
  module Xmi
    module Parsers
      module XmiBase
        # Generalization/inheritance serialization methods for XMI parsing

        # @param klass [Lutaml::Model::Serializable]
        # @return [Hash]
        def serialize_generalization(klass, options = {})
          general_hash, next_general_node_id = get_top_level_general_hash(
            klass, options
          )
          return general_hash unless next_general_node_id

          general_hash[:general] = serialize_generalization_attributes(
            next_general_node_id, options
          )

          general_hash
        end

        # @param klass [Lutaml::Model::Serializable]
        # @return [Array<Hash>]
        def get_top_level_general_hash(klass, options = {}) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          general_hash, next_general_node_id = get_general_hash(
            klass.id, options
          )
          general_hash[:name] = klass.name
          general_hash[:type] = klass.type
          general_hash[:definition] =
            lookup_element_prop_documentation(klass.id)
          general_hash[:stereotype] = doc_node_attribute_value(
            klass.id, "stereotype"
          )

          [general_hash, next_general_node_id]
        end

        # @param general_id [String]
        # @return [Array<Hash>]
        # @note get generalization node and its owned attributes
        def serialize_generalization_attributes(general_id, options = {}) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          general_hash, next_general_node_id = get_general_hash(general_id,
                                                                options)

          if next_general_node_id
            general_hash[:general] = serialize_generalization_attributes(
              next_general_node_id, options
            )
          end

          general_hash
        end

        # @param general_node [Lutaml::Model::Serializable]
        # @return [Hash]
        def get_general_attributes(general_node)
          serialize_class_attributes(general_node, with_assoc: true)
        end

        # @param general_node [Lutaml::Model::Serializable]
        # @return [String]
        def get_next_general_node_id(general_node)
          general_node.generalization.first&.general
        end

        # @param general_id [String]
        # @return [Array<Hash>]
        def get_general_hash(general_id, options = {}) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          general_node = find_packaged_element_by_id(general_id)
          return [] unless general_node

          general_node_attrs = get_general_attributes(general_node)
          general_upper_klass = find_upper_level_packaged_element(general_id)
          next_general_node_id = get_next_general_node_id(general_node)

          [
            {
              general_id: general_id,
              general_name: general_node.name,
              general_attributes: general_node_attrs,
              general_upper_klass: ::Lutaml::Xmi::LiquidDrops::PackageDrop
                .new(general_upper_klass, nil, options),
              general: {},
            },
            next_general_node_id,
          ]
        end
      end
    end
  end
end
