# frozen_string_literal: true

require_relative "base_model"

module Lutaml
  module Qea
    module Models
      # Represents a constraint type definition from t_constrainttypes table
      #
      # This table provides reference data for constraint types used in OCL
      # constraints. These are NOT instances of constraints, but the type
      # definitions themselves (Invariant, Pre-condition, Post-condition,
      # Process).
      #
      # @example
      #   constraint_type = EaConstraintType.new
      #   constraint_type.constraint #=> "Invariant"
      #   constraint_type.description #=> "A state the object must always..."
      class EaConstraintType < BaseModel
        attribute :constraint, Lutaml::Model::Type::String
        attribute :description, Lutaml::Model::Type::String
        attribute :notes, Lutaml::Model::Type::String

        def self.table_name
          "t_constrainttypes"
        end

        # Primary key is Constraint (text)
        def self.primary_key_column
          "Constraint"
        end

        # Friendly name for constraint type
        # @return [String]
        def name
          constraint
        end

        # Check if this is an invariant type
        # @return [Boolean]
        def invariant?
          constraint == "Invariant"
        end

        # Check if this is a pre-condition type
        # @return [Boolean]
        def precondition?
          constraint == "Pre-condition"
        end

        # Check if this is a post-condition type
        # @return [Boolean]
        def postcondition?
          constraint == "Post-condition"
        end

        # Check if this is a process type
        # @return [Boolean]
        def process?
          constraint == "Process"
        end
      end
    end
  end
end
