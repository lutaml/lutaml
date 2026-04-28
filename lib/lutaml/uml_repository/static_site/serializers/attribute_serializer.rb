# frozen_string_literal: true

require_relative "../../../uml/model_helpers"

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
            {
              id: id,
              name: attribute.name,
              type: attribute.type,
              visibility: attribute.visibility,
              owner: @id_generator.class_id(owner),
              ownerName: owner.name,
              cardinality: serialize_cardinality(attribute.cardinality),
              definition: format_definition(attribute.definition),
              stereotypes: normalize_stereotypes(
                attribute.respond_to?(:stereotype) ? attribute.stereotype : nil,
              ),
              isStatic: attribute.respond_to?(:is_static) ? attribute.is_static : false,
              isReadOnly: attribute.respond_to?(:is_read_only) ? attribute.is_read_only : false,
              defaultValue: attribute.respond_to?(:default) ? attribute.default : nil,
            }
          end

          private

          def serialize_cardinality(cardinality)
            return nil unless cardinality

            {
              min: cardinality.min,
              max: cardinality.max,
            }
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
end
