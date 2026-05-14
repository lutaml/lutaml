# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Serializers
        class AttributeSerializer
          include Lutaml::Uml::ModelHelpers

          def initialize(repository, id_generator, options)
            @repository = repository
            @id_generator = id_generator
            @options = options
          end

          def build_map
            attributes = {}
            @repository.classes_index.each do |klass|
              next unless klass.attributes

              klass.attributes.each do |attr|
                id = @id_generator.attribute_id(attr, klass)
                attributes[id] = serialize(attr, klass, id)
              end
            end
            attributes
          end

          def serialize(attribute, owner, id)
            Models::SpaAttribute.new(
              id: id,
              name: attribute.name,
              type: attribute.type,
              visibility: attribute.visibility,
              owner: @id_generator.class_id(owner),
              owner_name: owner.name,
              cardinality: serialize_cardinality(attribute.cardinality),
              definition: format_definition(attribute.definition),
              stereotypes: normalize_stereotypes(attribute.stereotype),
              is_static: attribute.is_static,
              is_read_only: attribute.is_read_only,
              default_value: attribute.default,
            )
          end

          private

          def serialize_cardinality(cardinality)
            return nil unless cardinality

            Models::SpaCardinality.new(
              min: cardinality.min,
              max: cardinality.max,
            )
          end
        end
      end
    end
  end
end
