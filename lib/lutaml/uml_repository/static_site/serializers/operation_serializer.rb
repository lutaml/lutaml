# frozen_string_literal: true

require_relative "../models/spa_operation"
require_relative "../models/spa_parameter"

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
              next unless klass.operations

              klass.operations.each do |op|
                id = @id_generator.operation_id(op, klass)
                operations[id] = serialize(op, klass, id)
              end
            end
            operations
          end

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

          private

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
