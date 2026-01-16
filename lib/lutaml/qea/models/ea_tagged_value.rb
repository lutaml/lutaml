# frozen_string_literal: true

require_relative "base_model"

module Lutaml
  module Qea
    module Models
      # EA Tagged Value model
      #
      # Represents tagged values (custom metadata) attached to UML elements
      # in the t_taggedvalue table.
      #
      # @example Create from database row
      #   row = {
      #     "PropertyID" => "{GUID}",
      #     "ElementID" => "{ELEMENT-GUID}",
      #     "BaseClass" => "ASSOCIATION_SOURCE",
      #     "TagValue" => "sequenceNumber|15$ea_notes=Unique integer...",
      #     "Notes" => nil
      #   }
      #   tagged_value = EaTaggedValue.from_db_row(row)
      class EaTaggedValue < BaseModel
        attribute :property_id, :string
        attribute :element_id, :string
        attribute :base_class, :string
        attribute :tag_value, :string
        attribute :notes, :string

        # @return [Symbol] Primary key column name
        def self.primary_key_column
          :property_id
        end

        # @return [String] Database table name
        def self.table_name
          "t_taggedvalue"
        end

        # Create from database row
        #
        # @param row [Hash] Database row with string keys
        # @return [EaTaggedValue, nil] New instance or nil if row is nil
        def self.from_db_row(row)
          return nil if row.nil?

          new(
            property_id: row["PropertyID"],
            element_id: row["ElementID"],
            base_class: row["BaseClass"],
            tag_value: row["TagValue"],
            notes: row["Notes"],
          )
        end

        # Parse tag name from TagValue field
        #
        # TagValue format: "tagName|value$ea_notes=description"
        # or "tagName$ea_notes=description"
        #
        # @return [String, nil] Tag name
        def tag_name
          return nil unless tag_value

          # Split on | or $ to get the tag name
          parts = tag_value.split(/[|$]/, 2)
          parts[0]&.strip
        end

        # Parse tag value from TagValue field
        #
        # TagValue format: "tagName|value$ea_notes=description"
        #
        # @return [String, nil] Tag value
        def parsed_value
          return nil unless tag_value

          # Check if there's a pipe separator
          return nil unless tag_value.include?("|")

          # Split on pipe first
          parts = tag_value.split("|", 2)
          return nil if parts.length < 2

          # Get the value part (before $)
          value_part = parts[1].split("$", 2)[0]
          value_part&.strip
        end

        # Parse notes from TagValue field
        #
        # Extract ea_notes if present in TagValue
        #
        # @return [String, nil] Extracted notes
        def parsed_notes # rubocop:disable Metrics/CyclomaticComplexity
          return notes if notes && !notes.empty?
          return nil unless tag_value&.include?("$ea_notes=")

          # Extract ea_notes value
          parts = tag_value.split("$ea_notes=", 2)
          parts[1]&.strip if parts.length > 1
        end
      end
    end
  end
end
