# frozen_string_literal: true

require_relative "id_generator"
require_relative "models/spa_association"
require_relative "models/spa_association_end"
require_relative "models/spa_cardinality"

module Lutaml
  module UmlRepository
    module StaticSite
      module AssociationSerialization
        private

        def build_associations_map
          associations = {}

          repository.associations_index.each do |assoc|
            id = @id_generator.association_id(assoc)
            associations[id] = serialize_association(assoc, id)
          end

          associations
        end

        def serialize_association(association, id)
          assoc_name = association.name
          if assoc_name.nil? || assoc_name.empty?
            assoc_name = association.owner_end_attribute_name
            assoc_name = if assoc_name.nil? || assoc_name.empty?
                           association.member_end_attribute_name
                         end
          end

          Models::SpaAssociation.new(
            id: id,
            xmi_id: association.xmi_id,
            name: assoc_name,
            type: "Association",
            definition: format_definition(association.definition),
            source: build_association_source(association),
            target: build_association_target(association),
          )
        end

        def build_association_source(association)
          return nil unless association.owner_end

          Models::SpaAssociationEnd.new(
            klass: association.owner_end_xmi_id,
            class_name: association.owner_end,
            role: association.owner_end_attribute_name,
            cardinality: serialize_cardinality(association.owner_end_cardinality),
            aggregation: association.owner_end_type,
          )
        end

        def build_association_target(association)
          return nil unless association.member_end

          Models::SpaAssociationEnd.new(
            klass: association.member_end_xmi_id,
            class_name: association.member_end,
            role: association.member_end_attribute_name,
            cardinality: serialize_cardinality(association.member_end_cardinality),
            aggregation: association.member_end_type,
          )
        end

        def serialize_cardinality(cardinality)
          return nil unless cardinality

          Models::SpaCardinality.new(
            min: cardinality.min,
            max: cardinality.max,
          )
        end

        def format_definition(definition)
          return nil if definition.nil? || definition.empty?

          formatted = definition.strip
          if @options[:max_definition_length] &&
              formatted.length > @options[:max_definition_length]
            formatted = "#{formatted[0...@options[:max_definition_length]]}..."
          end
          if @options[:format_definitions]
            formatted = formatted.gsub(%r{(https?://[^\s]+)}, '[\1](\1)')
          end
          formatted
        end
      end
    end
  end
end
