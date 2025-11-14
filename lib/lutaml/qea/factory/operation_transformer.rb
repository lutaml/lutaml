# frozen_string_literal: true

require_relative "base_transformer"
require "lutaml/uml"

module Lutaml
  module Qea
    module Factory
      # Transforms EA operations to UML operations
      class OperationTransformer < BaseTransformer
        # Transform EA operation to UML operation
        # @param ea_operation [EaOperation] EA operation model
        # @return [Lutaml::Uml::Operation] UML operation
        def transform(ea_operation)
          return nil if ea_operation.nil?

          Lutaml::Uml::Operation.new.tap do |op|
            op.name = ea_operation.name
            op.return_type = ea_operation.type
            op.visibility = map_visibility(ea_operation.scope)
            op.xmi_id = ea_operation.ea_guid

            # Build parameter type string from operation parameters
            op.parameter_type = build_parameter_type(ea_operation)

            # Map definition/notes
            op.definition = ea_operation.notes unless
              ea_operation.notes.nil? || ea_operation.notes.empty?

            # Map stereotype if present
            if ea_operation.stereotype && !ea_operation.stereotype.empty?
              op.stereotype = [ea_operation.stereotype]
            end
          end
        end

        private

        # Build parameter type string from operation parameters
        # @param ea_operation [EaOperation] EA operation
        # @return [String, nil] Parameter type string
        def build_parameter_type(ea_operation)
          # Load parameters for this operation
          params = load_parameters(ea_operation.operationid)
          return nil if params.empty?

          # Filter out return parameters and build parameter string
          input_params = params.reject(&:return?)
          return nil if input_params.empty?

          input_params.map do |param|
            type_str = param.type || "void"
            "#{param.name}: #{type_str}"
          end.join(", ")
        end

        # Load parameters for an operation
        # @param operation_id [Integer] Operation ID
        # @return [Array<EaOperationParam>] Operation parameters
        def load_parameters(operation_id)
          return [] if operation_id.nil?

          # Query t_operationparams table
          query = "SELECT * FROM t_operationparams WHERE OperationID = ? " \
                  "ORDER BY Pos"
          rows = database.connection.execute(query, operation_id)

          rows.map do |row|
            Models::EaOperationParam.from_db_row(row)
          end
        end
      end
    end
  end
end
