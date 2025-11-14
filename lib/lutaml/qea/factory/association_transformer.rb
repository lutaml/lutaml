# frozen_string_literal: true

require_relative "base_transformer"
require_relative "tagged_value_transformer"
require "lutaml/uml"

module Lutaml
  module Qea
    module Factory
      # Transforms EA connectors (Association type) to UML associations
      class AssociationTransformer < BaseTransformer
        # Transform EA connector to UML association
        # @param ea_connector [EaConnector] EA connector model
        # @return [Lutaml::Uml::Association] UML association
        def transform(ea_connector)
          return nil if ea_connector.nil?
          return nil unless ea_connector.association?

          Lutaml::Uml::Association.new.tap do |assoc|
            # Map basic properties
            assoc.name = ea_connector.name unless
              ea_connector.name.nil? || ea_connector.name.empty?
            assoc.xmi_id = ea_connector.ea_guid

            # Map source (owner) end
            source_obj = find_object(ea_connector.start_object_id)
            if source_obj
              assoc.owner_end = source_obj.name
              assoc.owner_end_xmi_id = source_obj.ea_guid
              assoc.owner_end_attribute_name = ea_connector.sourcerole
              assoc.owner_end_cardinality = build_cardinality_from_string(
                ea_connector.sourcecard,
              )
            end

            # Map target (member) end
            target_obj = find_object(ea_connector.end_object_id)
            if target_obj
              assoc.member_end = target_obj.name
              assoc.member_end_xmi_id = target_obj.ea_guid
              assoc.member_end_attribute_name = ea_connector.destrole
              assoc.member_end_cardinality = build_cardinality_from_string(
                ea_connector.destcard,
              )
            end

            # Map definition/notes
            assoc.definition = ea_connector.notes unless
              ea_connector.notes.nil? || ea_connector.notes.empty?

            # Map stereotype
            if ea_connector.stereotype && !ea_connector.stereotype.empty?
              assoc.stereotype = [ea_connector.stereotype]
            end

            # Load and transform tagged values
            assoc.tagged_values = load_tagged_values(ea_connector.ea_guid)
          end
        end

        private

        # Find object by ID
        # @param object_id [Integer] Object ID
        # @return [EaObject, nil] EA object or nil if not found
        def find_object(object_id)
          return nil if object_id.nil?

          query = "SELECT * FROM t_object WHERE Object_ID = ?"
          rows = database.connection.execute(query, object_id)
          return nil if rows.empty?

          Models::EaObject.from_db_row(rows.first)
        end

        # Build cardinality from string
        # @param cardinality_str [String] Cardinality string
        # @return [Lutaml::Uml::Cardinality, nil] Cardinality object
        def build_cardinality_from_string(cardinality_str)
          return nil if cardinality_str.nil? || cardinality_str.empty?

          parsed = parse_cardinality(cardinality_str)
          return nil if parsed[:min].nil? && parsed[:max].nil?

          Lutaml::Uml::Cardinality.new.tap do |card|
            card.min = parsed[:min]
            card.max = parsed[:max]
          end
        end

        # Load and transform tagged values for an association
        # @param ea_guid [String] Element GUID
        # @return [Array<Lutaml::Uml::TaggedValue>] UML tagged values
        def load_tagged_values(ea_guid)
          return [] if ea_guid.nil?
          return [] unless database.tagged_values

          # Filter tagged values for this element from the in-memory collection
          ea_tags = database.tagged_values.select do |tag|
            tag.element_id == ea_guid
          end

          # Transform to UML tagged values
          tag_transformer = TaggedValueTransformer.new(database)
          tag_transformer.transform_collection(ea_tags)
        end
      end
    end
  end
end
