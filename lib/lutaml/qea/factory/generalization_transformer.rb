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
              gen.general_id = normalize_guid_to_xmi_format(supertype_obj.ea_guid, "EAID")
              gen.general_name = supertype_obj.name

              # Find the package/upper class for the general
              if supertype_obj.package_id
                parent_package = find_package(supertype_obj.package_id)
                if parent_package
                  gen.general_upper_klass = extract_package_prefix(parent_package)
                end
              end
            end

            if subtype_obj
              gen.name = subtype_obj.name
              gen.type = "uml:Class"
            end

            # Map definition/notes
            gen.definition = ea_connector.notes unless
              ea_connector.notes.nil? || ea_connector.notes.empty?

            # Map stereotype
            gen.stereotype = supertype_obj&.stereotype unless
              supertype_obj&.stereotype.nil? || supertype_obj&.stereotype.empty?

            # Set has_general flag
            gen.has_general = !supertype_obj.nil?

            # Note: owned_props, assoc_props, inherited_props, inherited_assoc_props
            # will be populated later during post-processing phase
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

        # Find package by ID
        # @param package_id [Integer] Package ID
        # @return [EaPackage, nil] EA package or nil if not found
        def find_package(package_id)
          return nil if package_id.nil?
          return nil unless database.packages

          database.packages.find { |pkg| pkg.package_id == package_id }
        end

        # Extract package prefix from package
        # @param package [EaPackage] EA package
        # @return [String, nil] Package prefix or nil
        def extract_package_prefix(package)
          return nil unless package

          # Try to extract a meaningful prefix from package name
          # Common patterns: "ModelRoot::i-UR::urf" -> "urf"
          parts = package.name&.split("::")
          parts&.last
        end
      end
    end
  end
end
