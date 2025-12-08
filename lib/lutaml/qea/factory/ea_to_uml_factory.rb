# frozen_string_literal: true

require_relative "reference_resolver"
require_relative "document_builder"
require_relative "package_transformer"
require_relative "class_transformer"
require_relative "association_transformer"
require_relative "diagram_transformer"

module Lutaml
  module Qea
    module Factory
      # Main factory for orchestrating EA to UML transformation
      # Implements Facade pattern for complete model transformation
      class EaToUmlFactory
        attr_reader :database, :options, :resolver

        # Initialize factory with EA database
        # @param database [Lutaml::Qea::Database] Loaded EA database
        # @param options [Hash] Transformation options
        # @option options [Boolean] :include_diagrams Include diagrams (default: true)
        # @option options [Boolean] :validate Validate output (default: true)
        # @option options [String] :document_name Document name
        def initialize(database, options = {})
          @database = database
          @options = default_options.merge(options)
          @resolver = ReferenceResolver.new
          @transformers = {}
        end

        # Create complete UML document from EA database
        # @return [Lutaml::Uml::Document] Complete UML document
        def create_document
          builder = DocumentBuilder.new(
            name: options[:document_name] || "EA Model",
          )

          # Transform packages with hierarchy (includes all classes)
          packages = transform_packages

          # Transform associations (references classes by xmi_id)
          associations = transform_associations

          # Collect class-level associations from packages
          class_associations = collect_class_associations(packages)

          # Build document with both connector-level and class-level associations
          builder.add_packages(packages)
            .add_associations(associations)
            .add_associations(class_associations)

          # Add diagrams if requested
          if options[:include_diagrams]
            transform_diagrams
            # Note: diagrams are stored in packages, not at document level
          end

          builder.build(validate: options[:validate])
        end

        # Transform all packages with hierarchy
        # @return [Array<Lutaml::Uml::Package>] Root packages
        def transform_packages
          # Get root packages (those without parent)
          root_packages = database.packages.select do |pkg|
            pkg.parent_id.nil? || pkg.parent_id.zero?
          end

          # Transform each root package with its hierarchy
          package_transformer = get_transformer(:package)
          root_packages.map do |ea_package|
            uml_package = package_transformer.transform_with_hierarchy(
              ea_package,
              include_children: true,
            )

            # Register package and all descendants in resolver
            register_package_hierarchy(uml_package)

            uml_package
          end.compact
        end

        # Transform all classes
        # @return [Array<Lutaml::Uml::Class>] All UML classes
        def transform_classes
          class_transformer = get_transformer(:class)

          # Get all class-type objects
          ea_classes = database.objects.find_by_type("Class")
          ea_interfaces = database.objects.find_by_type("Interface")
          all_class_objects = ea_classes + ea_interfaces

          uml_classes = class_transformer.transform_collection(
            all_class_objects,
          )

          # Register all classes in resolver
          uml_classes.each do |uml_class|
            register_element(uml_class)
          end

          uml_classes
        end

        # Transform all associations
        # @return [Array<Lutaml::Uml::Association>] All UML associations
        def transform_associations
          association_transformer = get_transformer(:association)

          # Get all association-type connectors
          ea_associations = database.connectors.select(&:association?)

          uml_associations = association_transformer.transform_collection(
            ea_associations,
          )

          # Register all associations in resolver
          uml_associations.each do |uml_assoc|
            register_element(uml_assoc)
          end

          uml_associations
        end

        # Transform all diagrams
        # @return [Array<Lutaml::Uml::Diagram>] All UML diagrams
        def transform_diagrams
          diagram_transformer = get_transformer(:diagram)
          diagram_transformer.transform_collection(database.diagrams)
        end

        # Use custom transformers
        # @param transformers [Hash] Custom transformer instances
        # @option transformers [PackageTransformer] :package
        # @option transformers [ClassTransformer] :class
        # @option transformers [AssociationTransformer] :association
        # @option transformers [DiagramTransformer] :diagram
        # @return [self] For method chaining
        def with_transformers(transformers)
          @transformers.merge!(transformers)
          self
        end

        private

        # Default transformation options
        # @return [Hash] Default options
        def default_options
          {
            include_diagrams: true,
            validate: true,
            document_name: "EA Model",
          }
        end

        # Get or create transformer by type
        # @param type [Symbol] Transformer type
        # @return [BaseTransformer] Transformer instance
        def get_transformer(type)
          return @transformers[type] if @transformers.key?(type)

          @transformers[type] = case type
                                when :package
                                  PackageTransformer.new(database)
                                when :class
                                  ClassTransformer.new(database)
                                when :association
                                  AssociationTransformer.new(database)
                                when :diagram
                                  DiagramTransformer.new(database)
                                else
                                  raise ArgumentError,
                                        "Unknown transformer type: #{type}"
                                end
        end

        # Register package and all its descendants in resolver
        # @param package [Lutaml::Uml::Package] Package to register
        # @return [void]
        def register_package_hierarchy(package)
          return if package.nil?

          # Register the package itself
          register_element(package)

          # Register all classes in the package
          package.classes&.each do |klass|
            register_element(klass)
          end

          # Register all enums in the package
          package.enums&.each do |enum|
            register_element(enum)
          end

          # Register all data types in the package
          package.data_types&.each do |data_type|
            register_element(data_type)
          end

          # Register all instances in the package
          package.instances&.each do |instance|
            register_element(instance)
          end

          # Recursively register child packages
          package.packages&.each do |child_package|
            register_package_hierarchy(child_package)
          end
        end

        # Register a single element in the resolver
        # @param element [Object] Element with xmi_id
        # @return [void]
        def register_element(element)
          return if element.nil? || element.xmi_id.nil?

          @resolver.register(element.xmi_id, element)
        end

        # Collect all associations from classes within package hierarchy
        # @param packages [Array<Lutaml::Uml::Package>] Root packages
        # @return [Array<Lutaml::Uml::Association>] All class-level associations
        def collect_class_associations(packages)
          associations = []
          
          packages.each do |package|
            collect_package_associations(package, associations)
          end
          
          associations
        end

        # Recursively collect associations from package and its descendants
        # @param package [Lutaml::Uml::Package] Package to collect from
        # @param associations [Array] Accumulator for associations
        # @return [void]
        def collect_package_associations(package, associations)
          # Collect from classes in this package
          if package.classes
            package.classes.each do |klass|
              if klass.respond_to?(:associations) && klass.associations
                associations.concat(klass.associations)
              end
            end
          end

          # Recursively collect from child packages
          if package.packages
            package.packages.each do |child_package|
              collect_package_associations(child_package, associations)
            end
          end
        end
      end
    end
  end
end
