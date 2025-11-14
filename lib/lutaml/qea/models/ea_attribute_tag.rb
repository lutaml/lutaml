# frozen_string_literal: true

require_relative "base_model"

module Lutaml
  module Qea
    module Models
      # EA Attribute Tag model
      #
      # Represents attribute-level tags (custom key-value metadata)
      # in the t_attributetag table. These are metadata properties
      # specific to GML/XML Schema encoding for attributes.
      #
      # @example Create from database row
      #   row = {
      #     "PropertyID" => 1,
      #     "ElementID" => 367,
      #     "Property" => "isMetadata",
      #     "VALUE" => "false",
      #     "NOTES" => nil,
      #     "ea_guid" => "{GUID}"
      #   }
      #   tag = EaAttributeTag.from_db_row(row)
      class EaAttributeTag < BaseModel
        attribute :property_id, :integer
        attribute :element_id, :integer
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
          "t_attributetag"
        end

        # Create from database row
        #
        # @param row [Hash] Database row with string keys
        # @return [EaAttributeTag, nil] New instance or nil if row is nil
        def self.from_db_row(row)
          return nil if row.nil?

          new(
            property_id: row["PropertyID"],
            element_id: row["ElementID"],
            property: row["Property"],
            value: row["VALUE"],
            notes: row["NOTES"],
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

        # Parse integer value
        #
        # @return [Integer, nil] Integer value if parseable, nil otherwise
        def integer_value
          return nil if value.nil?

          begin
            Integer(value)
          rescue StandardError
            nil
          end
        end
      end
    end
  end
end
