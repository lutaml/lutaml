# frozen_string_literal: true

require_relative "base_transformer"
require_relative "tagged_value_transformer"
require_relative "instance_transformer"
require_relative "enum_transformer"
require_relative "data_type_transformer"
require "lutaml/uml"

module Lutaml
  module Qea
    module Factory
      # Transforms EA packages to UML packages
      class PackageTransformer < BaseTransformer
        # Transform EA package to UML package
        # @param ea_package [EaPackage] EA package model
        # @return [Lutaml::Uml::Package] UML package
        def transform(ea_package) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          return nil if ea_package.nil?

          Lutaml::Uml::Package.new.tap do |pkg|
            # Map basic properties
            pkg.name = ea_package.name
            pkg.xmi_id = normalize_guid_to_xmi_format(ea_package.ea_guid,
                                                      "EAPK")

            # Map definition/notes
            pkg.definition = ea_package.notes unless
              ea_package.notes.nil? || ea_package.notes.empty?

            # Load and transform tagged values
            # TODO: Fix tagged_values assignment - temporarily commented out
            # pkg.tagged_values = load_tagged_values(ea_package.ea_guid)

            # Load stereotype from t_xref
            stereotype = load_stereotype(ea_package.ea_guid)
            pkg.stereotype = [stereotype] if stereotype

            # Note: Child packages and contents will be loaded separately
            # to avoid circular dependencies and allow lazy loading
            # Don't initialize collections - they have default values
          end
        end

        # Transform and build complete package hierarchy
        # @param ea_package [EaPackage] Root EA package
        # @param include_children [Boolean] Whether to recursively load children
        # @return [Lutaml::Uml::Package] Complete UML package with hierarchy
        def transform_with_hierarchy(ea_package, include_children: true)
          pkg = transform(ea_package)
          return pkg unless include_children

          # Load child packages
          child_packages = load_child_packages(ea_package.package_id)
          pkg.packages = child_packages.map do |child_pkg|
            transform_with_hierarchy(child_pkg, include_children: true)
          end

          # Load package contents (classes, diagrams, etc.)
          load_package_contents(pkg, ea_package.package_id)

          pkg
        end

        private

        # Load child packages
        # @param parent_id [Integer] Parent package ID
        # @return [Array<EaPackage>] Child packages
        def load_child_packages(parent_id)
          return [] if parent_id.nil?

          query = "SELECT * FROM t_package WHERE Parent_ID = ? " \
                  "ORDER BY TPos"
          rows = database.connection.execute(query, parent_id)

          rows.map { |row| Models::EaPackage.from_db_row(row) }
        end

        # Load package contents (objects and diagrams)
        # @param pkg [Lutaml::Uml::Package] UML package to populate
        # @param package_id [Integer] EA package ID
        def load_package_contents(pkg, package_id)
          return if package_id.nil?

          # Load objects (classes, etc.) in this package
          load_package_objects(pkg, package_id)

          # Load diagrams in this package
          load_package_diagrams(pkg, package_id)
        end

        # Load objects for a package
        # @param pkg [Lutaml::Uml::Package] UML package
        # @param package_id [Integer] Package ID
        def load_package_objects(pkg, package_id) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          query = "SELECT * FROM t_object WHERE Package_ID = ?"
          rows = database.connection.execute(query, package_id)

          ea_objects = rows.map { |row| Models::EaObject.from_db_row(row) }

          class_transformer = ClassTransformer.new(database)
          enum_transformer = EnumTransformer.new(database)
          data_type_transformer = DataTypeTransformer.new(database)
          instance_transformer = InstanceTransformer.new(database)

          ea_objects.each do |ea_obj|
            if enum_object?(ea_obj)
              uml_enum = enum_transformer.transform(ea_obj)
              pkg.enums << uml_enum if uml_enum
            elsif data_type_object?(ea_obj)
              uml_dt = data_type_transformer.transform(ea_obj)
              pkg.data_types << uml_dt if uml_dt
            elsif class_object?(ea_obj)
              uml_class = class_transformer.transform(ea_obj)
              pkg.classes << uml_class if uml_class
            elsif ea_obj.instance?
              uml_instance = instance_transformer.transform(ea_obj)
              pkg.instances << uml_instance if uml_instance
            end
          end
        end

        # Check if an EA object should be classified as an enum.
        # EA stores enums as either object_type="Enumeration" or
        # object_type="Class" with stereotype="enumeration".
        def enum_object?(ea_obj)
          ea_obj.enumeration? || stereotype_is?(ea_obj, "enumeration")
        end

        # Check if an EA object should be classified as a data type.
        def data_type_object?(ea_obj)
          ea_obj.data_type?
        end

        # Check if an EA object should be classified as a class.
        def class_object?(ea_obj)
          return false if enum_object?(ea_obj) || data_type_object?(ea_obj)

          ea_obj.uml_class? || ea_obj.interface? ||
            ea_obj.object_type == "Text" ||
            ea_obj.object_type == "ProxyConnector"
        end

        # Check if an object's stereotype matches (case-insensitive).
        def stereotype_is?(ea_obj, expected)
          return false unless ea_obj.stereotype

          ea_obj.stereotype.downcase == expected
        end

        # Load diagrams for a package
        # @param pkg [Lutaml::Uml::Package] UML package
        # @param package_id [Integer] Package ID
        def load_package_diagrams(pkg, package_id)
          diagram_transformer = DiagramTransformer.new(database)

          query = "SELECT * FROM t_diagram WHERE Package_ID = ?"
          rows = database.connection.execute(query, package_id)

          ea_diagrams = rows.map { |row| Models::EaDiagram.from_db_row(row) }
          pkg.diagrams = diagram_transformer.transform_collection(ea_diagrams)
        end

        # Load and transform tagged values for a package
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

        # Load stereotype from t_xref table
        # @param ea_guid [String] Element GUID
        # @return [String, nil] Stereotype value (as string to match XMI format)
        def load_stereotype(ea_guid) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          return nil if ea_guid.nil?
          return nil unless database.xrefs

          # Find stereotype xref from the in-memory collection
          xref = database.xrefs.find do |x|
            x.client == ea_guid &&
              x.name == "Stereotypes" && x.type == "element property"
          end

          return nil unless xref

          # Parse stereotype from Description field
          # Format: @STEREO;Name=ApplicationSchema;FQName=GML::ApplicationSchema;@ENDSTEREO;
          description = xref.description
          return nil if description.nil? || description.empty?

          # Extract the Name value from the @STEREO format
          if description =~ /@STEREO;Name=([^;]+);/
            return $1
          end

          nil
        end

        # Check if an object appears on any diagram
        # @param object_id [Integer] Object ID
        # @return [Boolean] True if object appears on a diagram
        def appears_on_diagram?(object_id)
          return false if object_id.nil?
          return false unless database.diagram_objects

          # Check if object appears in any diagram's objects
          database.diagram_objects.any? do |dobj|
            dobj.ea_object_id == object_id
          end
        end
      end
    end
  end
end
