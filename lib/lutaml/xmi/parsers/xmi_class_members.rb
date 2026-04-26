# frozen_string_literal: true

module Lutaml
  module Xmi
    module Parsers
      module XmiBase
        # Class member (attribute, operation, constraint) serialization methods

        # @param klass [Lutaml::Model::Serializable]
        # @return [Array<Hash>]
        # @note xpath .//ownedOperation
        def serialize_class_operations(klass) # rubocop:disable Metrics/MethodLength
          klass.owned_operation.filter_map do |operation|
            uml_type = operation.uml_type.first
            uml_type_idref = uml_type.idref if uml_type

            if operation.association.nil?
              {
                id: operation.id,
                xmi_id: uml_type_idref,
                name: operation.name,
                definition: lookup_attribute_documentation(operation.id),
              }
            end
          end
        end

        # @param klass_id [String]
        # @return [Array<Hash>]
        # @note xpath ./constraints/constraint
        def serialize_class_constraints(klass_id) # rubocop:disable Metrics/MethodLength
          connector_node = fetch_connector(klass_id)

          if connector_node
            # In ea-xmi-2.5.1, constraints are moved to source/target under
            # connectors
            constraints = %i[source target].map do |st|
              connector_node.send(st).constraints.constraint
            end.flatten

            constraints.map do |constraint|
              {
                name: HTMLEntities.new.decode(constraint.name),
                type: constraint.type,
                weight: constraint.weight,
                status: constraint.status,
              }
            end
          end
        end

        # @param klass_id [String]
        # @return [Lutaml::Model::Serializable]
        # @note xpath %(//element[@xmi:idref="#{klass['xmi:id']}"])
        def fetch_element(klass_id)
          xmi_index.find_element(klass_id)
        end

        # @param klass [Lutaml::Model::Serializable]
        # @param with_assoc [Boolean]
        # @return [Array<Hash>]
        # @note xpath .//ownedAttribute[@xmi:type="uml:Property"]
        def serialize_class_attributes(klass, with_assoc: false) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength
          owned_attributes = klass.owned_attribute.select do |attr|
            attr.type?("uml:Property")
          end

          owned_attributes.filter_map do |oa|
            if with_assoc || oa.association.nil?
              attrs = build_class_attributes(oa)

              if with_assoc && oa.association
                attrs[:association] = oa.association
                attrs[:definition] = loopup_assoc_def(oa.association)
                attrs[:type_ns] = get_ns_by_xmi_id(attrs[:xmi_id])
              end

              attrs
            end
          end
        end

        def loopup_assoc_def(association)
          connector = fetch_connector(association)
          connector&.documentation&.value
        end

        # @param type [String]
        # @return [String]
        def get_ns_by_type(type)
          return unless type

          p = find_klass_packaged_element_by_name(type)
          return unless p

          find_upper_level_packaged_element(p.id)&.name
        end

        # @param xmi_id [String]
        # @return [String]
        def get_ns_by_xmi_id(xmi_id)
          return unless xmi_id

          p = find_packaged_element_by_id(xmi_id)
          return unless p

          find_upper_level_packaged_element(p.id)&.name
        end

        # @param owned_attr [Lutaml::Model::Serializable]
        # @return [Hash]
        def build_class_attributes(owned_attr) # rubocop:disable Metrics/MethodLength
          uml_type = owned_attr.uml_type
          uml_type_idref = uml_type.idref if uml_type

          {
            id: owned_attr.id,
            name: owned_attr.name,
            type: lookup_entity_name(uml_type_idref) || uml_type_idref,
            xmi_id: uml_type_idref,
            is_derived: owned_attr.is_derived,
            cardinality: cardinality_min_max_value(
              owned_attr.lower_value&.value,
              owned_attr.upper_value&.value,
            ),
            definition: lookup_attribute_documentation(owned_attr.id),
          }
        end

        # @param min [String]
        # @param max [String]
        # @return [Hash]
        def cardinality_min_max_value(min, max)
          {
            min: min,
            max: max,
          }
        end
      end
    end
  end
end
