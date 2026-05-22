# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Serializers
        class OperationSerializer < Base
          def build_map
            operations = {}
            @repository.classes_index.each do |klass|
              next unless klass.operations

              klass.operations.each do |op|
                id = @id_generator.operation_id(op, klass)
                operations[id] = serialize(op, klass, id)
              end
            end
            operations
          end

          private

          def serialize(operation, owner, id)
            Models::SpaOperation.new(
              id: id,
              name: operation.name,
              visibility: operation.visibility,
              return_type: operation.return_type,
              owner: @id_generator.class_id(owner),
              owner_name: owner.name,
              parameters: serialize_parameters(operation),
              is_static: operation.is_static,
              is_abstract: operation.is_abstract,
            )
          end

          def serialize_parameters(operation)
            return [] unless operation.owned_parameter

            operation.owned_parameter.map do |param|
              Models::SpaParameter.new(
                name: param.name,
                type: param.type,
                direction: param.direction,
              )
            end
          end
        end
      end
    end
  end
end
