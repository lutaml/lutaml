# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Serializers
        class AssociationSerializer < Base
          def build_map
            associations = {}

            @repository.associations_index.each do |assoc|
              id = @id_generator.association_id(assoc)
              associations[id] = serialize(assoc, id)
            end

            associations
          end

          private

          def serialize(association, id)
            Models::SpaAssociation.new(
              id: id,
              xmi_id: association.xmi_id,
              name: resolve_association_name(association),
              type: "Association",
              definition: format_definition(association.definition, @options),
              source: build_association_source(association),
              target: build_association_target(association),
            )
          end

          def resolve_association_name(association)
            name = association.name
            return name if name && !name.empty?

            role = association.owner_end_attribute_name
            return role if role && !role.empty?

            association.member_end_attribute_name
          end

          def build_association_source(association)
            return nil unless association.owner_end

            Models::SpaAssociationEnd.new(
              klass: association.owner_end_xmi_id,
              class_name: association.owner_end,
              role: association.owner_end_attribute_name,
              cardinality: Models::SpaCardinality.from_uml(association.owner_end_cardinality),
              aggregation: association.owner_end_type,
            )
          end

          def build_association_target(association)
            return nil unless association.member_end

            Models::SpaAssociationEnd.new(
              klass: association.member_end_xmi_id,
              class_name: association.member_end,
              role: association.member_end_attribute_name,
              cardinality: Models::SpaCardinality.from_uml(association.member_end_cardinality),
              aggregation: association.member_end_type,
            )
          end
        end
      end
    end
  end
end
