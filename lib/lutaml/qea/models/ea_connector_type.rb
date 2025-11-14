# frozen_string_literal: true

require_relative "base_model"

module Lutaml
  module Qea
    module Models
      # Represents a connector type definition from t_connectortypes table
      #
      # This table provides reference data for connector/association types.
      # These define the available relationship types in UML models.
      #
      # @example
      #   connector_type = EaConnectorType.new
      #   connector_type.connector_type #=> "Association"
      #   connector_type.description #=> "Association"
      class EaConnectorType < BaseModel
        attribute :connector_type, Lutaml::Model::Type::String
        attribute :description, Lutaml::Model::Type::String

        def self.table_name
          "t_connectortypes"
        end

        # Primary key is Connector_Type (text)
        def self.primary_key_column
          "Connector_Type"
        end

        # Friendly name for connector type
        # @return [String]
        def name
          connector_type
        end

        # Check if this is an association type
        # @return [Boolean]
        def association?
          connector_type == "Association"
        end

        # Check if this is a generalization type
        # @return [Boolean]
        def generalization?
          connector_type == "Generalization"
        end

        # Check if this is an aggregation type
        # @return [Boolean]
        def aggregation?
          connector_type == "Aggregation"
        end

        # Check if this is a dependency type
        # @return [Boolean]
        def dependency?
          connector_type == "Dependency"
        end
      end
    end
  end
end
