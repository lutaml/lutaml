# frozen_string_literal: true

require_relative "base_transformer"
require_relative "attribute_transformer"
require_relative "tagged_value_transformer"
require "lutaml/uml"

module Lutaml
  module Qea
    module Factory
      # Transforms EA objects (Enumeration type) to UML enums
      class EnumTransformer < BaseTransformer
        # Transform EA object to UML enum
        # @param ea_object [EaObject] EA object model
        # @return [Lutaml::Uml::Enum] UML enum
        def transform(ea_object) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength
          return nil if ea_object.nil?
          return nil unless ea_object.enumeration?

          Lutaml::Uml::Enum.new.tap do |enum|
            # Map basic properties
            enum.name = ea_object.name
            enum.xmi_id = normalize_guid_to_xmi_format(ea_object.ea_guid,
                                                       "EAID")
            enum.visibility = map_visibility(ea_object.visibility)

            # Set package path
            enum.package_path = calculate_package_path(ea_object.package_id)

            # Map stereotype
            if ea_object.stereotype && !ea_object.stereotype.empty?
              enum.stereotype = ea_object.stereotype
            end

            # Map definition/notes
            enum.definition = ea_object.note unless
              ea_object.note.nil? || ea_object.note.empty?

            # Load enum values (stored as attributes in EA)
            enum.values = load_enum_values(ea_object.ea_object_id)

            # Load and transform tagged values
            enum.tagged_values = load_tagged_values(ea_object.ea_guid)
          end
        end

        private

        # Load enum values (literals) from attributes
        # @param object_id [Integer] Object ID
        # @return [Array<Lutaml::Uml::Value>] Enum values
        def load_enum_values(object_id) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          return [] if object_id.nil?

          query = "SELECT * FROM t_attribute WHERE Object_ID = ? ORDER BY Pos"
          rows = database.connection.execute(query, object_id)

          rows.map do |row|
            ea_attr = Models::EaAttribute.from_db_row(row)

            Lutaml::Uml::Value.new.tap do |value|
              value.name = ea_attr.name
              value.id = normalize_guid_to_xmi_format(ea_attr.ea_guid, "EAID")
              value.definition = ea_attr.notes unless
                ea_attr.notes.nil? || ea_attr.notes.empty?
            end
          end.compact
        end

        # Load and transform tagged values for an enum
        # @param ea_guid [String] Element GUID
        # @return [Array<Lutaml::Uml::TaggedValue>] UML tagged values
        def load_tagged_values(ea_guid)
          return [] if ea_guid.nil?
          return [] unless database.tagged_values

          ea_tags = database.tagged_values.select do |tag|
            tag.element_id == ea_guid
          end

          tag_transformer = TaggedValueTransformer.new(database)
          tag_transformer.transform_collection(ea_tags)
        end
      end
    end
  end
end
