# frozen_string_literal: true

require_relative "base_model"

module Lutaml
  module Qea
    module Models
      # Represents an operation parameter from the t_operationparams table
      # This represents method/operation parameters
      # Note: Has composite primary key (OperationID + Name)
      class EaOperationParam < BaseModel
        attribute :operationid, Lutaml::Model::Type::Integer
        attribute :name, Lutaml::Model::Type::String
        attribute :type, Lutaml::Model::Type::String
        attribute :default, Lutaml::Model::Type::String
        attribute :notes, Lutaml::Model::Type::String
        attribute :pos, Lutaml::Model::Type::Integer
        attribute :const, Lutaml::Model::Type::Integer
        attribute :style, Lutaml::Model::Type::String
        attribute :kind, Lutaml::Model::Type::String
        attribute :classifier, Lutaml::Model::Type::String
        attribute :ea_guid, Lutaml::Model::Type::String
        attribute :styleex, Lutaml::Model::Type::String

        def self.primary_key_column
          # Composite key: [:operationid, :name]
          # Return first component for compatibility
          :operationid
        end

        def self.table_name
          "t_operationparams"
        end

        # Returns composite primary key as array
        # @return [Array] [operationid, name]
        def composite_key
          [operationid, name]
        end

        # Check if parameter is constant
        # @return [Boolean]
        def constant?
          const == 1
        end

        # Check if parameter is input parameter
        # @return [Boolean]
        def input?
          kind&.downcase == "in"
        end

        # Check if parameter is output parameter
        # @return [Boolean]
        def output?
          kind&.downcase == "out"
        end

        # Check if parameter is input/output parameter
        # @return [Boolean]
        def inout?
          kind&.downcase == "inout"
        end

        # Check if parameter is return parameter
        # @return [Boolean]
        def return?
          kind&.downcase == "return"
        end
      end
    end
  end
end
