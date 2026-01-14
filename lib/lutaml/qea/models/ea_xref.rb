# frozen_string_literal: true

require_relative "base_model"

module Lutaml
  module Qea
    module Models
      # Represents a cross-reference from the t_xref table in EA database
      # Stores cross-references for stereotypes, properties, and relationships
      # between UML elements
      class EaXref < BaseModel
        attribute :xref_id, Lutaml::Model::Type::String
        attribute :name, Lutaml::Model::Type::String
        attribute :xref_type, Lutaml::Model::Type::String
        attribute :client, Lutaml::Model::Type::String
        attribute :supplier, Lutaml::Model::Type::String
        attribute :description, Lutaml::Model::Type::String

        def self.primary_key_column
          :xref_id
        end

        def self.table_name
          "t_xref"
        end

        # Create from database row
        #
        # @param row [Hash] Database row with string keys
        # @return [EaXref, nil] New instance or nil if row is nil
        def self.from_db_row(row)
          return nil if row.nil?

          new(
            xref_id: row["XrefID"],
            name: row["Name"],
            xref_type: row["Type"],
            client: row["Client"],
            supplier: row["Supplier"],
            description: row["Description"],
          )
        end

        # Convenience aliases
        alias_method :id, :xref_id
        alias_method :type, :xref_type

        # Parse the Description field into structured data
        #
        # @return [Hash] Parsed description data
        def parsed_description
          return @parsed_description if defined?(@parsed_description)

          @parsed_description = parse_description_field(description)
        end

        # Check if this xref is for stereotypes
        # @return [Boolean]
        def stereotype?
          name == "Stereotypes" || description&.include?("@STEREO")
        end

        # Check if this xref is for custom properties
        # @return [Boolean]
        def custom_property?
          !description&.include?("@STEREO") && !description&.include?("@TAG")
        end

        # Check if this xref is for element properties
        # @return [Boolean]
        def element_property?
          xref_type == "element property"
        end

        # Check if this xref is for connector properties
        # @return [Boolean]
        def connector_property?
          xref_type&.include?("connector") && xref_type&.include?("property")
        end

        # Check if this xref is for diagram properties
        # @return [Boolean]
        def diagram_property?
          xref_type == "diagram properties"
        end

        # Check if this xref is for attribute properties
        # @return [Boolean]
        def attribute_property?
          xref_type == "attribute property"
        end

        private

        # Parse Description field with various formats
        #
        # Formats:
        # - @STEREO;Name=X;GUID={...};
        # - @TAG;Name=X;Value=Y;GUID={...};
        # - key=value;key=value;
        #
        # @param desc [String] Description field content
        # @return [Hash] Parsed data
        def parse_description_field(desc)
          return {} if desc.nil? || desc.empty?

          result = { raw: desc }

          # Detect format
          if desc.start_with?("@STEREO")
            result[:format] = :stereotype
            result[:data] = parse_stereo_format(desc)
          elsif desc.start_with?("@TAG")
            result[:format] = :tag
            result[:data] = parse_tag_format(desc)
          else
            result[:format] = :key_value
            result[:data] = parse_key_value_format(desc)
          end

          result
        end

        # Parse @STEREO format
        # Example: @STEREO;Name=FeatureType;GUID={ABC...};
        def parse_stereo_format(desc)
          data = {}
          parts = desc.sub(/^@STEREO;/, "").split(";")

          parts.each do |part|
            next if part.empty?

            key, value = part.split("=", 2)
            data[key.downcase.to_sym] = value if key && value
          end

          data
        end

        # Parse @TAG format
        # Example: @TAG;Name=author;Value=John;GUID={...};
        def parse_tag_format(desc)
          data = {}
          parts = desc.sub(/^@TAG;/, "").split(";")

          parts.each do |part|
            next if part.empty?

            key, value = part.split("=", 2)
            data[key.downcase.to_sym] = value if key && value
          end

          data
        end

        # Parse key=value format
        # Example: aggregation=composite;direction=source;
        def parse_key_value_format(desc)
          data = {}
          parts = desc.split(";")

          parts.each do |part|
            next if part.empty?

            key, value = part.split("=", 2)
            data[key.downcase.to_sym] = value if key && value
          end

          data
        end
      end
    end
  end
end
