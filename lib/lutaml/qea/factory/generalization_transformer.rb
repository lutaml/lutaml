# frozen_string_literal: true

require_relative "base_transformer"
require "lutaml/uml"

module Lutaml
  module Qea
    module Factory
      # Transforms EA connectors (Generalization type) to UML generalizations
      class GeneralizationTransformer < BaseTransformer
        # Transform EA connector to UML generalization
        # @param ea_connector [EaConnector, nil] EA connector model (nil for terminal nodes)
        # @param current_object [EaObject] Current object that owns this generalization
        # @return [Lutaml::Uml::Generalization] UML generalization
        def transform(ea_connector, current_object)
          return nil if current_object.nil?

          # ea_connector can be nil for terminal nodes (classes with no parent)
          if ea_connector && !ea_connector.generalization?
            return nil
          end

          Lutaml::Uml::Generalization.new.tap do |gen|
            # Map properties from CURRENT object (not parent)
            # This matches XMI's self-referential pattern
            gen.general_id = normalize_guid_to_xmi_format(current_object.ea_guid, "EAID")
            gen.general_name = current_object.name
            gen.name = current_object.name
            gen.type = "uml:Generalization"

            # Map definition from ea_connector notes
            if !ea_connector&.notes.nil? && !ea_connector&.notes&.empty?
              gen.definition = normalize_line_endings(ea_connector.notes)
            end

            # Map stereotype from current object
            gen.stereotype = current_object.stereotype unless
              current_object.stereotype.nil? || current_object.stereotype.empty?

            # Find the package/upper class for the current object
            if current_object.package_id
              current_package = find_package(current_object.package_id)
              if current_package
                gen.general_upper_klass = extract_package_prefix(current_package)
              end
            end

            # Set has_general flag based on whether parent exists
            # Use false (not nil) for terminal nodes to match XMI behavior
            gen.has_general = ea_connector ? !ea_connector.end_object_id.nil? : false

            # Note: general_attributes, attributes, owned_props, assoc_props,
            # general, inherited_props, inherited_assoc_props
            # will be populated in ClassTransformer.load_generalization
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
