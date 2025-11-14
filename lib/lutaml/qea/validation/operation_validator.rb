# frozen_string_literal: true

require_relative "base_validator"

module Lutaml
  module Qea
    module Validation
      # Validates operation references and structure
      class OperationValidator < BaseValidator
        def validate
          validate_parent_object_references
          validate_return_types
        end

        private

        def validate_parent_object_references
          operations.each do |op|
            unless reference_exists?("t_object", "object_id", op.ea_object_id)
              result.add_error(
                category: :missing_reference,
                entity_type: :operation,
                entity_id: op.operationid.to_s,
                entity_name: op.name,
                field: "object_id",
                reference: op.ea_object_id.to_s,
                message: "Parent object #{op.ea_object_id} does not exist",
              )
            end
          end
        end

        def validate_return_types
          operations.each do |op|
            next unless op.classifier && !op.classifier.empty?

            # Classifier can be either an object name or a primitive type
            next if primitive_type?(op.classifier)
            next if classifier_exists?(op.classifier)

            parent = database&.objects&.all&.find do |o|
              o.ea_object_id == op.ea_object_id
            end
            result.add_warning(
              category: :missing_reference,
              entity_type: :operation,
              entity_id: op.operationid.to_s,
              entity_name: "#{parent&.name}.#{op.name}()",
              field: "classifier",
              reference: op.classifier,
              message: "Return type '#{op.classifier}' not found",
            )
          end
        end

        def operations
          @operations ||= context[:operations] || []
        end

        def classifier_exists?(classifier_id)
          return false unless database

          # Classifier field contains object_id, not name
          database.objects.all.any? do |o|
            o.ea_object_id.to_s == classifier_id.to_s
          end
        end

        def primitive_type?(type_name)
          primitives = %w[
            Integer String Boolean Float Double Long Short Byte Char
            Date Time DateTime Decimal void Object Any
            int string bool float double long short byte char
          ]
          primitives.include?(type_name)
        end
      end
    end
  end
end
