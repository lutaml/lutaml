# frozen_string_literal: true

require_relative "base_transformer"
require_relative "tagged_value_transformer"
require "lutaml/uml"

module Lutaml
  module Qea
    module Factory
      # Transforms EA objects (Object type) to UML instances
      class InstanceTransformer < BaseTransformer
        # Transform EA object to UML instance
        # @param ea_object [EaObject] EA object model
        # @return [Lutaml::Uml::Instance] UML instance
        def transform(ea_object) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          return nil if ea_object.nil?
          return nil unless ea_object.instance?

          Lutaml::Uml::Instance.new.tap do |instance|
            # Map basic properties
            instance.name = ea_object.name
            instance.xmi_id = normalize_guid_to_xmi_format(ea_object.ea_guid,
                                                           "EAID")

            # Map classifier (the class this is an instance of)
            if ea_object.classifier && ea_object.classifier > 0
              classifier_obj = find_classifier(ea_object.classifier)
              if classifier_obj
                instance.classifier = classifier_obj.name
              end
            elsif ea_object.classifier_guid && !ea_object.classifier_guid.empty?
              classifier_obj = find_classifier_by_guid(
                ea_object.classifier_guid,
              )
              if classifier_obj
                instance.classifier = classifier_obj.name
              end
            end

            # Map definition/notes
            instance.definition = ea_object.note unless
              ea_object.note.nil? || ea_object.note.empty?

            # Load and transform tagged values
            instance.tagged_values = load_tagged_values(ea_object.ea_guid)
          end
        end

        private

        # Find classifier object by ID
        # @param classifier_id [Integer] Classifier object ID
        # @return [EaObject, nil] EA object or nil if not found
        def find_classifier(classifier_id)
          return nil if classifier_id.nil? || classifier_id.zero?

          query = "SELECT * FROM t_object WHERE Object_ID = ?"
          rows = database.connection.execute(query, classifier_id)
          return nil if rows.empty?

          Models::EaObject.from_db_row(rows.first)
        end

        # Find classifier object by GUID
        # @param classifier_guid [String] Classifier GUID
        # @return [EaObject, nil] EA object or nil if not found
        def find_classifier_by_guid(classifier_guid)
          return nil if classifier_guid.nil? || classifier_guid.empty?

          query = "SELECT * FROM t_object WHERE ea_guid = ?"
          rows = database.connection.execute(query, classifier_guid)
          return nil if rows.empty?

          Models::EaObject.from_db_row(rows.first)
        end

        # Load and transform tagged values for an instance
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
