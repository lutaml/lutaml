# frozen_string_literal: true

require_relative "base_transformer"
require "lutaml/uml"

module Lutaml
  module Qea
    module Factory
      # Transforms EA connectors (Generalization type) to UML generalizations
      class GeneralizationTransformer < BaseTransformer
        # Transform EA connector to UML generalization
        # @param ea_connector [EaConnector] EA connector model
        # @return [Lutaml::Uml::Generalization] UML generalization
        def transform(ea_connector)
          return nil if ea_connector.nil?
          return nil unless ea_connector.generalization?

          Lutaml::Uml::Generalization.new.tap do |gen|
            # Map source (subtype) and target (supertype)
            # In generalization, start_object_id is the subtype
            # end_object_id is the supertype
            subtype_obj = find_object(ea_connector.start_object_id)
            supertype_obj = find_object(ea_connector.end_object_id)

            if supertype_obj
              gen.general_id = supertype_obj.ea_guid
              gen.general_name = supertype_obj.name
            end

            if subtype_obj
              gen.name = subtype_obj.name
              gen.type = subtype_obj.object_type
            end

            # Map definition/notes
            gen.definition = ea_connector.notes unless
              ea_connector.notes.nil? || ea_connector.notes.empty?

            # Map stereotype
            gen.stereotype = ea_connector.stereotype unless
              ea_connector.stereotype.nil? || ea_connector.stereotype.empty?

            # Set has_general flag
            gen.has_general = !supertype_obj.nil?
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
      end
    end
  end
end
