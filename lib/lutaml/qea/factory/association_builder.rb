# frozen_string_literal: true

require_relative "base_transformer"

module Lutaml
  module Qea
    module Factory
      class AssociationBuilder < BaseTransformer
        ASSOC_TYPES = ["Association", "Aggregation", "Composition"].freeze

        def load_class_associations(object_id, object_guid)
          return [] if object_id.nil?

          normalized_owner_xmi_id = normalize_guid_to_xmi_format(object_guid,
                                                                 "EAID")

          assoc_connectors = database.connectors_for_object(object_id)
            .select { |c| ASSOC_TYPES.include?(c.connector_type) }

          assoc_connectors.filter_map do |ea_connector|
            build_association(ea_connector, object_id, normalized_owner_xmi_id)
          end
        end

        def load_association_attributes(object_id)
          return [] if object_id.nil?

          assoc_connectors = database.connectors_for_object(object_id)
            .select { |c| ASSOC_TYPES.include?(c.connector_type) }
          obj = find_object_by_id(object_id)
          obj_pkg_name = find_package_name(obj&.package_id)

          assoc_connectors.filter_map do |ea_connector|
            if ea_connector.start_object_id == object_id
              build_end_attribute(ea_connector, obj, obj_pkg_name)
            elsif ea_connector.end_object_id == object_id
              build_start_attribute(ea_connector, obj, obj_pkg_name)
            end
          end
        end

        def create_association_attribute( # rubocop:disable Metrics/ParameterLists
          name:, type:, type_xmi_id:,
          association_xmi_id:, cardinality:, definition:,
          gen_name:, name_ns:, type_ns:, is_src: true
        )
          Lutaml::Uml::GeneralAttribute.new.tap do |attr|
            assign_assoc_attr_basic(attr, name, type, gen_name, definition,
                                    name_ns, type_ns)
            attr.xmi_id = normalize_guid_to_xmi_format(type_xmi_id, "EAID")
            attr.association = normalize_guid_to_xmi_format(
              association_xmi_id, "EAID"
            )
            attr.has_association = true
            attr.id = normalize_guid_to_xmi_src_dst_format(
              association_xmi_id, "EAID", is_src
            )
            attr.cardinality = build_cardinality(cardinality)
          end
        end

        private

        def assign_assoc_attr_basic(attr, name, type, gen_name,
                                    definition, name_ns, type_ns)
          attr.name = name
          attr.type = type
          attr.gen_name = gen_name
          attr.definition = definition
          attr.name_ns = name_ns
          attr.type_ns = type_ns
        end

        def build_association(ea_connector, object_id, normalized_owner_xmi_id)
          is_start = ea_connector.start_object_id == object_id
          owner_role = is_start ? ea_connector.destrole : ea_connector.sourcerole
          return nil if owner_role.nil? || owner_role.empty?

          member_obj = resolve_member_object(ea_connector, is_start)
          return nil unless member_obj

          member_role = resolve_member_role(ea_connector, is_start, member_obj)
          cardinality_str = is_start ? ea_connector.destcard : ea_connector.sourcecard

          Lutaml::Uml::Association.new.tap do |assoc|
            assoc.xmi_id = normalize_guid_to_xmi_format(ea_connector.ea_guid,
                                                        "EAID")
            assoc.name = ea_connector.name unless ea_connector.name.nil? || ea_connector.name.empty?
            assign_association_ends(assoc, object_id, normalized_owner_xmi_id,
                                    owner_role, member_obj, member_role)
            assoc.member_end_type = ea_connector.connector_type&.downcase
            assoc.member_end_cardinality = build_cardinality(cardinality_str)
          end
        end

        def assign_association_ends(assoc, object_id, owner_xmi_id,
                                    owner_role, member_obj, member_role)
          assoc.owner_end = find_object_by_id(object_id)&.name
          assoc.owner_end_xmi_id = owner_xmi_id
          assoc.owner_end_attribute_name = owner_role
          assoc.member_end = member_obj.name
          assoc.member_end_xmi_id = normalize_guid_to_xmi_format(
            member_obj.ea_guid, "EAID"
          )
          assoc.member_end_attribute_name = member_role
        end

        def resolve_member_object(ea_connector, is_start)
          peer_id = is_start ? ea_connector.end_object_id : ea_connector.start_object_id
          find_object_by_id(peer_id)
        end

        def resolve_member_role(ea_connector, is_start, member_obj)
          role = is_start ? ea_connector.sourcerole : ea_connector.destrole
          role.nil? || role.empty? ? member_obj.name : role
        end

        def build_end_attribute(ea_connector, obj, obj_pkg_name)
          return nil if ea_connector.destrole.nil? || ea_connector.destrole.empty?

          target_obj = find_object_by_id(ea_connector.end_object_id)
          return nil unless target_obj

          create_association_attribute(
            name: ea_connector.destrole,
            type: target_obj.name,
            type_xmi_id: target_obj.ea_guid,
            association_xmi_id: ea_connector.ea_guid,
            cardinality: ea_connector.destcard,
            definition: ea_connector.notes,
            gen_name: obj.name,
            name_ns: obj_pkg_name,
            type_ns: find_package_name(target_obj.package_id),
            is_src: false,
          )
        end

        def build_start_attribute(ea_connector, obj, obj_pkg_name)
          return nil if ea_connector.sourcerole.nil? || ea_connector.sourcerole.empty?

          source_obj = find_object_by_id(ea_connector.start_object_id)
          return nil unless source_obj

          create_association_attribute(
            name: ea_connector.sourcerole,
            type: source_obj.name,
            type_xmi_id: source_obj.ea_guid,
            association_xmi_id: ea_connector.ea_guid,
            cardinality: ea_connector.sourcecard,
            definition: ea_connector.notes,
            gen_name: obj.name,
            name_ns: obj_pkg_name,
            type_ns: find_package_name(source_obj.package_id),
          )
        end

        def build_cardinality(cardinality_str)
          return nil unless cardinality_str && !cardinality_str.empty?

          parsed = parse_cardinality(cardinality_str)
          return nil unless parsed[:min] || parsed[:max]

          Lutaml::Uml::Cardinality.new.tap do |card|
            card.min = parsed[:min]
            card.max = parsed[:max]
          end
        end

        def find_package_name(package_id)
          return nil if package_id.nil?

          database.find_package(package_id)&.name
        end
      end
    end
  end
end
