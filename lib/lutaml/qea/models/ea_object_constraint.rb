# frozen_string_literal: true

require_relative "base_model"

module Lutaml
  module Qea
    module Models
      # EA Object Constraint model
      #
      # Represents OCL constraints attached to UML objects in the
      # t_objectconstraint table.
      #
      # @example Create from database row
      #   row = {
      #     "Object_ID" => 4,
      #     "Constraint" => "count(self.legalConstraints) >= 1",
      #     "ConstraintType" => "Invariant",
      #     "Weight" => "0.0",
      #     "Notes" => nil,
      #     "Status" => "Approved"
      #   }
      #   constraint = EaObjectConstraint.from_db_row(row)
      class EaObjectConstraint < BaseModel
        attribute :constraint_id, :integer
        attribute :ea_object_id, :integer
        attribute :constraint, :string
        attribute :constraint_type, :string
        attribute :weight, :float
        attribute :notes, :string
        attribute :status, :string

        # @return [Symbol] Primary key column name
        def self.primary_key_column
          :constraint_id
        end

        # @return [String] Database table name
        def self.table_name
          "t_objectconstraint"
        end

        # Create from database row
        #
        # @param row [Hash] Database row with string keys
        # @return [EaObjectConstraint, nil] New instance or nil if row is nil
        def self.from_db_row(row)
          return nil if row.nil?

          new(
            constraint_id: row["ConstraintID"],
            ea_object_id: row["Object_ID"],
            constraint: row["Constraint"],
            constraint_type: row["ConstraintType"],
            weight: row["Weight"]&.to_f,
            notes: row["Notes"],
            status: row["Status"],
          )
        end
      end
    end
  end
end
