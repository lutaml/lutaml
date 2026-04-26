# frozen_string_literal: true

module Lutaml
  module Xmi
    module Parsers
      module XmiBase
        # Enum and data type serialization methods for XMI parsing

        # @param package [Lutaml::Model::Serializable]
        # @return [Array<Hash>]
        # @note xpath ./packagedElement[@xmi:type="uml:Enumeration"]
        def serialize_model_enums(package) # rubocop:disable Metrics/MethodLength
          enums = package.packaged_element.select do |e|
            e.type?("uml:Enumeration")
          end

          enums.map do |enum|
            {
              xmi_id: enum.id,
              name: enum.name,
              values: serialize_enum_owned_literal(enum),
              definition: doc_node_attribute_value(enum.id, "documentation"),
              stereotype: doc_node_attribute_value(enum.id, "stereotype"),
            }
          end
        end

        # @param enum [Lutaml::Model::Serializable]
        # @return [Hash]
        # @note xpath .//ownedLiteral[@xmi:type="uml:EnumerationLiteral"]
        def serialize_enum_owned_literal(enum) # rubocop:disable Metrics/MethodLength
          owned_literals = enum.owned_literal.select do |owned_literal|
            owned_literal.type? "uml:EnumerationLiteral"
          end

          owned_literals.map do |owned_literal|
            uml_type_id = owned_literal&.uml_type&.idref

            {
              name: owned_literal.name,
              type: lookup_entity_name(uml_type_id) || uml_type_id,
              definition: lookup_attribute_documentation(owned_literal.id),
            }
          end
        end

        # @param model [Lutaml::Model::Serializable]
        # @return [Array<Hash>]
        # @note xpath ./packagedElement[@xmi:type="uml:DataType"]
        def serialize_model_data_types(model) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          all_data_type_elements = []
          select_all_packaged_elements(
            all_data_type_elements, model, "uml:DataType"
          )
          all_data_type_elements.map do |klass|
            {
              xmi_id: klass.id,
              name: klass.name,
              attributes: serialize_class_attributes(klass),
              operations: serialize_class_operations(klass),
              associations: serialize_model_associations(klass.id),
              constraints: serialize_class_constraints(klass.id),
              is_abstract: doc_node_attribute_value(klass.id, "isAbstract"),
              definition: doc_node_attribute_value(klass.id, "documentation"),
              stereotype: doc_node_attribute_value(klass.id, "stereotype"),
            }
          end
        end
      end
    end
  end
end
