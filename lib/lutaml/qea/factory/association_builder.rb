# frozen_string_literal: true

require_relative "base_transformer"

module Lutaml
  module Qea
    module Factory
      class AssociationBuilder < BaseTransformer
        ASSOC_TYPES = ["Association", "Aggregation", "Composition"].freeze

        def load_class_associations(object_id, object_guid)
          return [] if object_id.nil?

          associations = []
          normalized_owner_xmi_id = normalize_guid_to_xmi_format(object_guid,
                                                                 "EAID")

          assoc_connectors = database.connectors_for_object(object_id)
            .select { |c| ASSOC_TYPES.include?(c.connector_type) }

          assoc_connectors.each do |ea_connector|
            is_start = ea_connector.start_object_id == object_id

            owner_end_attribute_name = if is_start
                                         ea_connector.destrole
                                       else
                                         ea_connector.sourcerole
                                       end

            if owner_end_attribute_name.nil? || owner_end_attribute_name.empty?
              next
            end

            member_obj = if is_start
                           find_object_by_id(ea_connector.end_object_id)
                         else
                           find_object_by_id(ea_connector.start_object_id)
                         end
            next unless member_obj

            member_end_attribute_name = if is_start
                                          ea_connector.sourcerole
                                        else
                                          ea_connector.destrole
                                        end
            if member_end_attribute_name.nil? ||
                member_end_attribute_name.empty?
              member_end_attribute_name = member_obj.name
            end

            member_cardinality_str = if is_start
                                       ea_connector.destcard
                                     else
                                       ea_connector.sourcecard
                                     end

            associations << Lutaml::Uml::Association.new.tap do |assoc|
              assoc.xmi_id = normalize_guid_to_xmi_format(ea_connector.ea_guid,
                                                          "EAID")
              assoc.name = ea_connector.name unless ea_connector.name.nil? || ea_connector.name.empty?

              assoc.owner_end = find_object_by_id(object_id)&.name
              assoc.owner_end_xmi_id = normalized_owner_xmi_id
              assoc.owner_end_attribute_name = owner_end_attribute_name

              assoc.member_end = member_obj.name
              assoc.member_end_xmi_id = normalize_guid_to_xmi_format(
                member_obj.ea_guid, "EAID"
              )
              assoc.member_end_attribute_name = member_end_attribute_name

              assoc.member_end_type = ea_connector.connector_type&.downcase

              if member_cardinality_str && !member_cardinality_str.empty?
                parsed = parse_cardinality(member_cardinality_str)
                if parsed[:min] || parsed[:max]
                  assoc.member_end_cardinality = Lutaml::Uml::Cardinality.new
                    .tap do |card|
                      card.min = parsed[:min]
                      card.max = parsed[:max]
                    end
                end
              end
            end
          end

          associations.compact
        end

        def load_association_attributes(object_id)
          return [] if object_id.nil?

          attributes = []
          assoc_connectors = database.connectors_for_object(object_id)
            .select { |c| ASSOC_TYPES.include?(c.connector_type) }
          obj = find_object_by_id(object_id)
          obj_pkg_name = find_package_name(obj&.package_id)

          assoc_connectors.each do |ea_connector|
            if ea_connector.start_object_id == object_id
              next if ea_connector.destrole.nil? || ea_connector.destrole.empty?

              target_obj = find_object_by_id(ea_connector.end_object_id)
              next unless target_obj

              target_obj_pkg_name = find_package_name(target_obj.package_id)

              attributes << create_association_attribute(
                name: ea_connector.destrole,
                type: target_obj.name,
                type_xmi_id: target_obj.ea_guid,
                association_xmi_id: ea_connector.ea_guid,
                cardinality: ea_connector.destcard,
                definition: ea_connector.notes,
                gen_name: obj.name,
                name_ns: obj_pkg_name,
                type_ns: target_obj_pkg_name,
                is_src: false,
              )
            elsif ea_connector.end_object_id == object_id
              next if ea_connector.sourcerole.nil? || ea_connector.sourcerole.empty?

              source_obj = find_object_by_id(ea_connector.start_object_id)
              next unless source_obj

              source_obj_pkg_name = find_package_name(source_obj.package_id)

              attributes << create_association_attribute(
                name: ea_connector.sourcerole,
                type: source_obj.name,
                type_xmi_id: source_obj.ea_guid,
                association_xmi_id: ea_connector.ea_guid,
                cardinality: ea_connector.sourcecard,
                definition: ea_connector.notes,
                gen_name: obj.name,
                name_ns: obj_pkg_name,
                type_ns: source_obj_pkg_name,
              )
            end
          end

          attributes.compact
        end

        def create_association_attribute( # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/ParameterLists
          name:, type:, type_xmi_id:,
          association_xmi_id:, cardinality:, definition:,
          gen_name:, name_ns:, type_ns:, is_src: true
        )
          Lutaml::Uml::GeneralAttribute.new.tap do |attr|
            attr.name = name
            attr.type = type
            attr.gen_name = gen_name
            attr.definition = definition
            attr.xmi_id = normalize_guid_to_xmi_format(type_xmi_id, "EAID")
            attr.association = normalize_guid_to_xmi_format(
              association_xmi_id, "EAID"
            )
            attr.has_association = true
            attr.id = normalize_guid_to_xmi_src_dst_format(
              association_xmi_id, "EAID", is_src
            )
            attr.name_ns = name_ns
            attr.type_ns = type_ns

            if cardinality && !cardinality.empty?
              parsed = parse_cardinality(cardinality)
              if parsed[:min] || parsed[:max]
                attr.cardinality = Lutaml::Uml::Cardinality.new.tap do |card|
                  card.min = parsed[:min]
                  card.max = parsed[:max]
                end
              end
            end
          end
        end

        private

        def find_package_name(package_id)
          return nil if package_id.nil?
          database.find_package(package_id)&.name
        end
      end
    end
  end
end
