# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      # Association serialization concern for DataTransformer
      #
      # Extracts association-related serialization methods so
      # DataTransformer can remain focused on top-level orchestration.
      module AssociationSerialization
        private

        def build_associations_map
          associations = {}

          # Repository.associations_index collects from both:
          # - Document-level associations (XMI format)
          # - Class-level associations (QEA/EA format)
          repository.associations_index.each do |assoc|
            id = @id_generator.association_id(assoc)
            associations[id] = serialize_association(assoc, id)
          end

          associations
        end

        def serialize_association(association, id) # rubocop:disable Metrics/MethodLength
          # If association.name is nil, use the role name as fallback
          assoc_name = association.name
          if assoc_name.nil? || assoc_name.empty?
            assoc_name = association.owner_end_attribute_name
            assoc_name = if assoc_name.nil? || assoc_name.empty?
                           association.member_end_attribute_name
                         end
          end

          {
            id: id,
            xmiId: association.xmi_id,
            name: assoc_name,
            type: "Association",
            definition: format_definition(
              if association.respond_to?(:definition)
                association.definition
              end,
            ),
            source: build_association_source(association),
            target: build_association_target(association),
          }
        end

        def build_association_source(association)
          return nil unless association.owner_end

          {
            class: association.owner_end_xmi_id,
            className: association.owner_end,
            role: association.owner_end_attribute_name,
            cardinality: serialize_cardinality(
              association.owner_end_cardinality,
            ),
            aggregation: association.owner_end_type,
          }
        end

        def build_association_target(association)
          return nil unless association.member_end

          {
            class: association.member_end_xmi_id,
            className: association.member_end,
            role: association.member_end_attribute_name,
            cardinality: serialize_cardinality(
              association.member_end_cardinality,
            ),
            aggregation: association.member_end_type,
          }
        end

        def serialize_association_end(end_obj) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          return nil unless end_obj
          return nil unless end_obj.respond_to?(:type) && end_obj.type

          # end_obj.type can be a String (class name) or a Class object
          type_value = end_obj.type

          if type_value.is_a?(String)
            # Type is a string reference (class name)
            {
              class: nil, # Can't generate ID without class object
              className: type_value,
              role: end_obj.respond_to?(:name) ? end_obj.name : nil,
              cardinality: serialize_cardinality(
                if end_obj.respond_to?(:cardinality)
                  end_obj.cardinality
                end,
              ),
              navigable: if end_obj.respond_to?(:navigable?)
                           end_obj.navigable?
                         else
                           false
                         end,
              aggregation: if end_obj.respond_to?(:aggregation)
                             end_obj.aggregation
                           end,
              visibility: if end_obj.respond_to?(:visibility)
                            end_obj.visibility
                          end,
            }
          else
            # Type is a class object
            {
              class: @id_generator.class_id(type_value),
              className: if type_value.respond_to?(:name)
                           type_value.name
                         else
                           type_value.to_s
                         end,
              role: end_obj.respond_to?(:name) ? end_obj.name : nil,
              cardinality: serialize_cardinality(
                if end_obj.respond_to?(:cardinality)
                  end_obj.cardinality
                end,
              ),
              navigable: if end_obj.respond_to?(:navigable?)
                           end_obj.navigable?
                         else
                           false
                         end,
              aggregation: if end_obj.respond_to?(:aggregation)
                             end_obj.aggregation
                           end,
              visibility: if end_obj.respond_to?(:visibility)
                            end_obj.visibility
                          end,
            }
          end
        end
      end
    end
  end
end
