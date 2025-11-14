# frozen_string_literal: true

require_relative "base_model"

module Lutaml
  module Qea
    module Models
      # EA Object Property model
      #
      # Represents object-level properties (custom key-value metadata)
      # in the t_objectproperties table. These are metadata properties
      # specific to GML/XML Schema encoding.
      #
      # @example Create from database row
      #   row = {
      #     "PropertyID" => 1,
      #     "Object_ID" => 684,
      #     "Property" => "isCollection",
      #     "Value" => "false",
      #     "Notes" => "Values: true,false...",
      #     "ea_guid" => "{GUID}"
      #   }
      #   property = EaObjectProperty.from_db_row(row)
      class EaObjectProperty < BaseModel
        attribute :property_id, :integer
        attribute :ea_object_id, :integer
        attribute :property, :string
        attribute :value, :string
        attribute :notes, :string
        attribute :ea_guid, :string

        # @return [Symbol] Primary key column name
        def self.primary_key_column
          :property_id
        end

        # @return [String] Database table name
        def self.table_name
          "t_objectproperties"
        end

        # Create from database row
        #
        # @param row [Hash] Database row with string keys
        # @return [EaObjectProperty, nil] New instance or nil if row is nil
        def self.from_db_row(row)
          return nil if row.nil?

          new(
            property_id: row["PropertyID"],
            ea_object_id: row["Object_ID"],
            property: row["Property"],
            value: row["Value"],
            notes: row["Notes"],
            ea_guid: row["ea_guid"],
          )
        end

        # Get property name
        #
        # @return [String, nil] Property name
        def name
          property
        end

        # Get property value as string
        #
        # @return [String, nil] Property value
        def property_value
          value
        end

        # Parse boolean value
        #
        # @return [Boolean, nil] Boolean value if parseable, nil otherwise
        def boolean_value
          return nil if value.nil?

          case value.downcase
          when "true", "1", "yes"
            true
          when "false", "0", "no"
            false
          end
        end

        # Check if property is boolean type
        #
        # @return [Boolean] true if value is boolean
        def boolean?
          !boolean_value.nil?
        end
      end
    end
  end
end
