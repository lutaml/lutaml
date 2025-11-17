# frozen_string_literal: true

require_relative "base_transformer"
require_relative "tagged_value_transformer"
require_relative "instance_transformer"
require "lutaml/uml"

module Lutaml
  module Qea
    module Factory
      # Transforms EA packages to UML packages
      class PackageTransformer < BaseTransformer
        # Transform EA package to UML package
        # @param ea_package [EaPackage] EA package model
        # @return [Lutaml::Uml::Package] UML package
        def transform(ea_package)
          return nil if ea_package.nil?

          Lutaml::Uml::Package.new.tap do |pkg|
            # Map basic properties
            pkg.name = ea_package.name
            pkg.xmi_id = ea_package.ea_guid

            # Map definition/notes
            pkg.definition = ea_package.notes unless
              ea_package.notes.nil? || ea_package.notes.empty?

            # Load and transform tagged values
            pkg.tagged_values = load_tagged_values(ea_package.ea_guid)

            # Note: Child packages and contents will be loaded separately
            # to avoid circular dependencies and allow lazy loading
            pkg.packages = []
            pkg.classes = []
            pkg.enums = []
            pkg.data_types = []
            pkg.instances = []
            pkg.diagrams = []
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
        def load_package_objects(pkg, package_id)
          query = "SELECT * FROM t_object WHERE Package_ID = ?"
          rows = database.connection.execute(query, package_id)

          ea_objects = rows.map { |row| Models::EaObject.from_db_row(row) }

          # Transform classes
          class_transformer = ClassTransformer.new(database)
          ea_objects.select(&:uml_class?).each do |ea_obj|
            uml_class = class_transformer.transform(ea_obj)
            pkg.classes << uml_class if uml_class
          end

          # Transform instances (Object type)
          instance_transformer = InstanceTransformer.new(database)
          ea_objects.select(&:instance?).each do |ea_obj|
            uml_instance = instance_transformer.transform(ea_obj)
            pkg.instances << uml_instance if uml_instance
          end

          # Note: Enums and DataTypes could be added similarly
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
      end
    end
  end
end
