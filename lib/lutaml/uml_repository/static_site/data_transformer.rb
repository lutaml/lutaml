# frozen_string_literal: true

require_relative "id_generator"

module Lutaml
  module UmlRepository
    module StaticSite
      # Transforms a UmlRepository into a normalized JSON data structure
      # optimized for client-side navigation and search.
      #
      # The output follows a normalized structure with:
      # - Flat maps for packages, classes, attributes, associations
      # - References by stable IDs
      # - Hierarchical package tree for navigation
      #
      # @example
      #   repository = UmlRepository.from_package("model.lur")
      #   transformer = DataTransformer.new(repository)
      #   json_data = transformer.transform
      class DataTransformer
        attr_reader :repository, :id_generator, :options

        # Initialize transformer
        #
        # @param repository [UmlRepository] The repository to transform
        # @param options [Hash] Transformation options
        # @option options [Boolean] :include_diagrams Include diagram information
        # @option options [Boolean] :format_definitions Format definitions as markdown
        def initialize(repository, options = {})
          @repository = repository
          @options = default_options.merge(options)
          @id_generator = IDGenerator.new
        end

        # Transform repository to JSON structure
        #
        # @return [Hash] Normalized JSON data structure
        def transform
          {
            metadata: build_metadata,
            packageTree: build_package_tree,
            packages: build_packages_map,
            classes: build_classes_map,
            attributes: build_attributes_map,
            associations: build_associations_map,
            operations: build_operations_map,
            diagrams: (@options[:include_diagrams] ? build_diagrams_map : {}),
          }
        end

        private

        def default_options
          {
            include_diagrams: true,
            format_definitions: true,
            max_definition_length: nil,
          }
        end

        # Build metadata section
        def build_metadata
          {
            generated: Time.now.utc.iso8601,
            generator: "LutaML Static Site Generator",
            version: "1.0",
            statistics: build_statistics,
          }
        end

        # Build statistics
        def build_statistics
          {
            packages: repository.packages_index.size,
            classes: repository.classes_index.size,
            associations: repository.associations_index.size,
            attributes: count_total_attributes,
            operations: count_total_operations,
          }
        end

        def count_total_attributes
          repository.classes_index.sum do |klass|
            klass.attributes&.size || 0
          end
        end

        def count_total_operations
          repository.classes_index.sum do |klass|
            (klass.respond_to?(:operations) ? klass.operations&.size : 0) || 0
          end
        end

        # Build hierarchical package tree
        def build_package_tree
          root_packages = repository.packages_index.select do |pkg|
            !pkg.respond_to?(:namespace) || pkg.namespace.nil? || !pkg.namespace.is_a?(Lutaml::Uml::Package)
          end

          if root_packages.size == 1
            build_tree_node(root_packages.first)
          else
            # Multiple roots - create virtual root
            {
              id: "root",
              name: "Model",
              path: "",
              classCount: 0,
              children: root_packages.map { |pkg| build_tree_node(pkg) },
            }
          end
        end

        def build_tree_node(package)
          pkg_id = @id_generator.package_id(package)

          {
            id: pkg_id,
            name: package.name,
            path: package_path(package),
            classCount: package.classes&.size || 0,
            classes: (package.classes || []).map { |c| @id_generator.class_id(c) },
            children: (package.packages || []).map do |child|
              build_tree_node(child)
            end,
          }
        end

        # Build packages map
        def build_packages_map
          packages = {}

          repository.packages_index.each do |package|
            id = @id_generator.package_id(package)
            packages[id] = serialize_package(package, id)
          end

          packages
        end

        def serialize_package(package, id)
          {
            id: id,
            xmiId: package.respond_to?(:xmi_id) ? package.xmi_id : nil,
            name: package.name,
            path: package_path(package),
            definition: format_definition(package.respond_to?(:definition) ? package.definition : nil),
            stereotypes: package.respond_to?(:stereotype) ? (package.stereotype || []) : [],
            classes: (package.classes || []).map do |c|
              @id_generator.class_id(c)
            end,
            subPackages: (package.packages || []).map do |p|
              @id_generator.package_id(p)
            end,
            diagrams: package_diagrams(package).map do |d|
              @id_generator.diagram_id(d)
            end,
            parent: (package.respond_to?(:namespace) && package.namespace.is_a?(Lutaml::Uml::Package)) ? @id_generator.package_id(package.namespace) : nil,
          }
        end

        # Build classes map
        def build_classes_map
          classes = {}

          repository.classes_index.each do |klass|
            id = @id_generator.class_id(klass)
            classes[id] = serialize_class(klass, id)
          end

          classes
        end

        def serialize_class(klass, id)
          {
            id: id,
            xmiId: klass.xmi_id,
            name: klass.name,
            qualifiedName: qualified_name(klass),
            type: class_type(klass),
            package: package_id_for_class(klass),
            stereotypes: klass.respond_to?(:stereotype) ? (klass.stereotype || []) : [],
            definition: format_definition(klass.definition),
            attributes: (klass.attributes || []).map do |attr|
              @id_generator.attribute_id(attr, klass)
            end,
            operations: serialize_class_operations(klass),
            associations: find_class_associations(klass),
            generalizations: find_generalizations(klass),
            specializations: find_specializations(klass),
            isAbstract: klass.respond_to?(:is_abstract) ? klass.is_abstract : false,
            literals: serialize_literals(klass),
          }
        end

        # Build attributes map
        def build_attributes_map
          attributes = {}

          repository.classes_index.each do |klass|
            next unless klass.attributes

            klass.attributes.each do |attr|
              id = @id_generator.attribute_id(attr, klass)
              attributes[id] = serialize_attribute(attr, klass, id)
            end
          end

          attributes
        end

        def serialize_attribute(attribute, owner, id)
          {
            id: id,
            name: attribute.name,
            type: attribute.type,
            visibility: attribute.visibility,
            owner: @id_generator.class_id(owner),
            ownerName: owner.name,
            cardinality: serialize_cardinality(attribute.cardinality),
            definition: format_definition(attribute.definition),
            stereotypes: attribute.respond_to?(:stereotype) ? (attribute.stereotype || []) : [],
            isStatic: attribute.respond_to?(:is_static) ? attribute.is_static : false,
            isReadOnly: attribute.respond_to?(:is_read_only) ? attribute.is_read_only : false,
            defaultValue: attribute.respond_to?(:default) ? attribute.default : nil,
          }
        end

        # Build associations map
        def build_associations_map
          associations = {}

          repository.associations_index.each do |assoc|
            id = @id_generator.association_id(assoc)
            associations[id] = serialize_association(assoc, id)
          end

          associations
        end

        def serialize_association(association, id)
          # Association model has member_end/owner_end as strings (class names)
          # Use member_end_xmi_id, member_end_type etc for more details
          {
            id: id,
            xmiId: association.xmi_id,
            name: association.name,
            type: "Association",
            source: build_association_source(association),
            target: build_association_target(association),
          }
        end

        def build_association_source(association)
          return nil unless association.owner_end

          {
            class: association.owner_end_xmi_id,
            className: association.owner_end,
            role: association.owner_end_attribute_name,
            cardinality: serialize_cardinality(association.owner_end_cardinality),
            aggregation: association.owner_end_type,
          }
        end

        def build_association_target(association)
          return nil unless association.member_end

          {
            class: association.member_end_xmi_id,
            className: association.member_end,
            role: association.member_end_attribute_name,
            cardinality: serialize_cardinality(association.member_end_cardinality),
            aggregation: association.member_end_type,
          }
        end

        def serialize_association_end(end_obj)
          return nil unless end_obj
          return nil unless end_obj.respond_to?(:type) && end_obj.type

          # end_obj.type can be a String (class name) or a Class object
          type_value = end_obj.type

          if type_value.is_a?(String)
            # Type is a string reference (class name)
            {
              class: nil, # Can't generate ID without class object
              className: type_value,
              role: end_obj.respond_to?(:name) ? end_obj.name : nil,
              cardinality: serialize_cardinality(end_obj.respond_to?(:cardinality) ? end_obj.cardinality : nil),
              navigable: end_obj.respond_to?(:navigable?) ? end_obj.navigable? : false,
              aggregation: end_obj.respond_to?(:aggregation) ? end_obj.aggregation : nil,
              visibility: end_obj.respond_to?(:visibility) ? end_obj.visibility : nil,
            }
          else
            # Type is a class object
            {
              class: @id_generator.class_id(type_value),
              className: type_value.respond_to?(:name) ? type_value.name : type_value.to_s,
              role: end_obj.respond_to?(:name) ? end_obj.name : nil,
              cardinality: serialize_cardinality(end_obj.respond_to?(:cardinality) ? end_obj.cardinality : nil),
              navigable: end_obj.respond_to?(:navigable?) ? end_obj.navigable? : false,
              aggregation: end_obj.respond_to?(:aggregation) ? end_obj.aggregation : nil,
              visibility: end_obj.respond_to?(:visibility) ? end_obj.visibility : nil,
            }
          end
        end

        # Build operations map
        def build_operations_map
          operations = {}

          repository.classes_index.each do |klass|
            next unless klass.respond_to?(:operations) && klass.operations

            klass.operations.each do |op|
              id = @id_generator.operation_id(op, klass)
              operations[id] = serialize_operation(op, klass, id)
            end
          end

          operations
        end

        def serialize_operation(operation, owner, id)
          {
            id: id,
            name: operation.name,
            visibility: operation.visibility,
            returnType: operation.return_type,
            owner: @id_generator.class_id(owner),
            ownerName: owner.name,
            parameters: serialize_parameters(operation),
            isStatic: operation.respond_to?(:is_static) ? operation.is_static : false,
            isAbstract: operation.respond_to?(:is_abstract) ? operation.is_abstract : false,
          }
        end

        def serialize_parameters(operation)
          return [] unless operation.respond_to?(:owned_parameter) && operation.owned_parameter

          operation.owned_parameter.map do |param|
            {
              name: param.name,
              type: param.type,
              direction: param.respond_to?(:direction) ? param.direction : "in",
            }
          end
        end

        # Build diagrams map
        def build_diagrams_map
          diagrams = {}

          repository.diagrams_index.each do |diagram|
            id = @id_generator.diagram_id(diagram)
            diagrams[id] = serialize_diagram(diagram, id)
          end

          diagrams
        rescue StandardError
          # Diagrams may not be available in all repositories
          {}
        end

        def serialize_diagram(diagram, id)
          {
            id: id,
            xmiId: diagram.xmi_id,
            name: diagram.name,
            type: diagram.diagram_type,
            package: find_diagram_package(diagram),
          }
        end

        # Helper methods

        def package_path(package)
          return package.name unless package.respond_to?(:namespace) && package.namespace
          return package.name unless package.namespace.is_a?(Lutaml::Uml::Package)

          "#{package_path(package.namespace)}::#{package.name}"
        end

        def qualified_name(klass)
          path_parts = []
          current = klass

          # Walk up the namespace chain
          while current
            if current.is_a?(Lutaml::Uml::TopElement)
              path_parts.unshift(current.name)
              current = current.respond_to?(:namespace) ? current.namespace : nil
            elsif current.is_a?(Lutaml::Uml::Package)
              path_parts.unshift(current.name)
              current = current.namespace
            else
              break
            end
          end

          path_parts.join("::")
        end

        def class_type(klass)
          klass.class.name.split("::").last
        end

        def package_id_for_class(klass)
          ns = klass.respond_to?(:namespace) ? klass.namespace : nil
          return nil unless ns&.is_a?(Lutaml::Uml::Package)

          @id_generator.package_id(ns)
        end

        def package_diagrams(package)
          return [] unless @options[:include_diagrams]

          repository.diagrams_in_package(package_path(package))
        rescue StandardError
          []
        end

        def find_diagram_package(diagram)
          # Try to find which package owns this diagram
          repository.packages_index.each do |pkg|
            diagrams = package_diagrams(pkg)
            if diagrams.any? { |d| d.xmi_id == diagram.xmi_id }
              return @id_generator.package_id(pkg)
            end
          end
          nil
        rescue StandardError
          nil
        end

        def serialize_cardinality(cardinality)
          return nil unless cardinality

          {
            min: cardinality.min,
            max: cardinality.max,
          }
        end

        def format_definition(definition)
          return nil if definition.nil? || definition.empty?

          formatted = definition.strip

          # Optionally truncate
          if @options[:max_definition_length] && formatted.length > @options[:max_definition_length]
            formatted = "#{formatted[0...@options[:max_definition_length]]}..."
          end

          # Optionally format as markdown (basic)
          if @options[:format_definitions]
            formatted = format_as_markdown(formatted)
          end

          formatted
        end

        def format_as_markdown(text)
          # Basic markdown formatting
          # - Preserve line breaks
          # - Convert URLs to links
          text.gsub(%r{(https?://[^\s]+)}, '[\\1](\\1)')
        end

        def serialize_class_operations(klass)
          return [] unless klass.respond_to?(:operations) && klass.operations

          klass.operations.map { |op| @id_generator.operation_id(op, klass) }
        end

        def find_class_associations(klass)
          associations = repository.associations_of(klass)
          associations.map { |assoc| @id_generator.association_id(assoc) }
        rescue StandardError
          []
        end

        def find_generalizations(klass)
          parent = repository.supertype_of(klass)
          parent ? [@id_generator.class_id(parent)] : []
        rescue StandardError
          []
        end

        def find_specializations(klass)
          children = repository.subtypes_of(klass)
          children.map { |child| @id_generator.class_id(child) }
        rescue StandardError
          []
        end

        def serialize_literals(klass)
          return [] unless klass.is_a?(Lutaml::Uml::Enum) && klass.owned_literal

          klass.owned_literal.map do |literal|
            {
              name: literal.name,
              definition: format_definition(literal.definition),
            }
          end
        rescue StandardError
          []
        end
      end
    end
  end
end
