# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Serializers
        class AttributeSerializer < Base
          def build_map
            attributes = {}
            @repository.classes_index.each do |klass|
              next unless klass.attributes

              klass.attributes.each do |attr|
                id = @id_generator.attribute_id(attr, klass)
                attributes[id] = serialize_attribute(attr, klass, id)
              end
            end
            attributes
          end
        end
      end
    end
  end
end
