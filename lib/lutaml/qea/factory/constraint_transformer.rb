# frozen_string_literal: true

require_relative "base_transformer"
require "lutaml/uml"

module Lutaml
  module Qea
    module Factory
      # Transforms EA ObjectConstraint to UML Constraint
      #
      # This transformer converts Enterprise Architect constraint definitions
      # (typically OCL constraints) to standard UML Constraint objects.
      #
      # @example Transform a constraint
      #   ea_constraint = Models::EaObjectConstraint.new(
      #     constraint_id: 1,
      #     object_id: 4,
      #     constraint: "count(self.legalConstraints) >= 1",
      #     constraint_type: "Invariant",
      #     weight: 0.0,
      #     status: "Approved"
      #   )
      #   transformer = ConstraintTransformer.new(database)
      #   uml_constraint = transformer.transform(ea_constraint)
      class ConstraintTransformer < BaseTransformer
        # Transform EA constraint to UML Constraint
        #
        # @param ea_constraint [Models::EaObjectConstraint] EA constraint model
        # @return [Lutaml::Uml::Constraint, nil] UML constraint or nil
        def transform(ea_constraint) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          return nil unless ea_constraint

          Lutaml::Uml::Constraint.new.tap do |constraint|
            # Generate unique ID for the constraint
            constraint.xmi_id = "constraint_#{ea_constraint.constraint_id}" if
              ea_constraint.constraint_id

            # Generate descriptive name from constraint body or use ID
            constraint.name = constraint_name(ea_constraint)

            # Map constraint properties
            constraint.body = ea_constraint.constraint
            constraint.type = ea_constraint.constraint_type
            constraint.weight = ea_constraint.weight&.to_s
            constraint.status = ea_constraint.status
          end
        end

        private

        # Generate descriptive name from constraint body
        #
        # Extracts the first meaningful part of the constraint body to use
        # as a descriptive name. Falls back to a generic name if extraction
        # fails.
        #
        # @param ea_constraint [Models::EaObjectConstraint] EA constraint
        # @return [String] Constraint name
        def constraint_name(ea_constraint) # rubocop:disable Metrics/MethodLength
          return "constraint_#{ea_constraint.constraint_id}" unless
            ea_constraint.constraint

          body = ea_constraint.constraint.to_s.strip

          # Try to extract a meaningful name from the constraint body
          # Take first 50 chars or until special chars
          name_part = body[0..50].split(/[()<>=\s]/).first&.strip

          if name_part && !name_part.empty?
            name_part
          else
            "constraint_#{ea_constraint.constraint_id}"
          end
        end
      end
    end
  end
end
