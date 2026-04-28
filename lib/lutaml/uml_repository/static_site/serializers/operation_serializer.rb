# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Serializers
        class OperationSerializer
          def initialize(repository, id_generator)
            @repository = repository
            @id_generator = id_generator
          end

          def build_map
            operations = {}
            @repository.classes_index.each do |klass|
              next unless klass.respond_to?(:operations) && klass.operations

              klass.operations.each do |op|
                id = @id_generator.operation_id(op, klass)
                operations[id] = serialize(op, klass, id)
              end
            end
            operations
          end

          def serialize(operation, owner, id)
            {
              id: id,
              name: operation.name,
              visibility: operation.visibility,
              returnType: operation.return_type,
              owner: @id_generator.class_id(owner),
              ownerName: owner.name,
              parameters: serialize_parameters(operation),
              isStatic: operation.respond_to?(:is_static) ? operation.is_static : false,
              isAbstract: operation.respond_to?(:is_abstract) ? operation.is_abstract : false,
            }
          end

          private

          def serialize_parameters(operation)
            return [] unless operation.respond_to?(:owned_parameter) && operation.owned_parameter

            operation.owned_parameter.map do |param|
              {
                name: param.name,
                type: param.type,
                direction: param.respond_to?(:direction) ? param.direction : "in",
              }
            end
          end
        end
      end
    end
  end
end
