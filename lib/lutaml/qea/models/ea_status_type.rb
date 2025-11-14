# frozen_string_literal: true

require_relative "base_model"

module Lutaml
  module Qea
    module Models
      # Represents a status type definition from t_statustypes table
      #
      # This table provides reference data for status values that can be
      # assigned to UML elements (Approved, Implemented, Mandatory, etc.).
      #
      # @example
      #   status_type = EaStatusType.new
      #   status_type.status #=> "Approved"
      #   status_type.description #=> "Item is approved"
      class EaStatusType < BaseModel
        attribute :status, Lutaml::Model::Type::String
        attribute :description, Lutaml::Model::Type::String

        def self.table_name
          "t_statustypes"
        end

        # Primary key is Status (text)
        def self.primary_key_column
          "Status"
        end

        # Friendly name for status
        # @return [String]
        def name
          status
        end

        # Check if this is the Approved status
        # @return [Boolean]
        def approved?
          status == "Approved"
        end

        # Check if this is the Implemented status
        # @return [Boolean]
        def implemented?
          status == "Implemented"
        end

        # Check if this is the Mandatory status
        # @return [Boolean]
        def mandatory?
          status == "Mandatory"
        end

        # Check if this is the Proposed status
        # @return [Boolean]
        def proposed?
          status == "Proposed"
        end

        # Check if this is the Validated status
        # @return [Boolean]
        def validated?
          status == "Validated"
        end
      end
    end
  end
end
