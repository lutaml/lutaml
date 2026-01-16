# frozen_string_literal: true

require_relative "../uml/package_path"
require_relative "../uml/qualified_name"

module Lutaml
  module UmlRepository
    # IndexBuilder builds fast lookup indexes from a Lutaml::Uml::Document
    #
    # This class creates immutable hash indexes that enable O(1) lookups for:
    # - Package paths (e.g., "ModelRoot::i-UR::urf")
    # - Qualified names (e.g., "ModelRoot::i-UR::urf::Building")
    # - Stereotypes (e.g., "featureType" => [Class, Class, ...])
    # - Inheritance graph (parent_qname => [child_qname, ...])
    # - Diagram index (package_id => [Diagram, ...])
    # - Package to path mapping (package_id => path)
    # - Class to qualified name mapping (class_id => qualified_name)
    # - Classes (class_id => Class)
    # - Associations (association_id => Association)
    #
    # All indexes are frozen to ensure immutability.
    #
    # @example Building all indexes from a document
    #   indexes = IndexBuilder.build_all(document)
    #   package = indexes[:package_paths]["ModelRoot::i-UR"]
    #   klass = indexes[:qualified_names]["ModelRoot::i-UR::Building"]
    class IndexBuilder
      ROOT_PACKAGE_NAME = "ModelRoot"

      # Build all indexes from a UML document
      #
      # @param document [Lutaml::Uml::Document] The UML document to index
      # @return [Hash] A frozen hash containing all indexes with keys:
      #   - :package_paths - Maps package paths to Package objects
      #   - :qualified_names - Maps qualified names to
      #     Class/DataType/Enum objects
      #   - :stereotypes - Groups classes by stereotype
      #   - :inheritance_graph - Maps parent qualified names to child
      #     qualified names
      #   - :diagram_index - Maps package IDs/paths to Diagram objects
      #   - :package_to_path - Maps package XMI IDs to paths
      #   - :class_to_qname - Maps class XMI IDs to qualified names
      #   - :classes - Maps class XMI IDs to Class objects
      #   - :associations - Maps association XMI IDs to Association objects
      def self.build_all(document) # rubocop:disable Metrics/MethodLength
        {
          package_paths: build_package_paths(document),
          qualified_names: build_qualified_names(document),
          stereotypes: build_stereotypes(document),
          inheritance_graph: build_inheritance_graph(document, nil),
          diagram_index: build_diagram_index(document, nil),
          package_to_path: build_package_to_path(document),
          class_to_qname: build_class_to_qname(document),
          classes: build_classes(document),
          associations: build_associations(document),
        }.freeze
      end

      # Build package paths index
      #
      # @param document [Lutaml::Uml::Document] The UML document
      # @return [Hash] Frozen hash mapping package paths to Package objects
      def self.build_package_paths(document)
        builder = new(document)
        builder.build_package_path_index
        builder.instance_variable_get(:@package_paths).freeze
      end

      def self.build_package_to_path(document)
        builder = new(document)
        builder.build_package_path_index
        builder.instance_variable_get(:@package_to_path).freeze
      end

      # Build qualified names index
      #
      # @param document [Lutaml::Uml::Document] The UML document
      # @return [Hash] Frozen hash mapping qualified names to Class objects
      def self.build_qualified_names(document)
        builder = new(document)
        builder.build_qualified_name_index
        builder.instance_variable_get(:@qualified_names).freeze
      end

      def self.build_class_to_qname(document)
        builder = new(document)
        builder.build_qualified_name_index
        builder.instance_variable_get(:@class_to_qname).freeze
      end

      def self.build_classes(document)
        builder = new(document)
        builder.build_qualified_name_index
        builder.instance_variable_get(:@classes).freeze
      end

      def self.build_associations(document)
        builder = new(document)
        # build_association_index needs @qualified_names to collect
        # class-level associations
        builder.build_qualified_name_index
        builder.build_association_index
        builder.instance_variable_get(:@associations).freeze
      end

      # Build stereotypes index
      #
      # @param document [Lutaml::Uml::Document] The UML document
      # @return [Hash] Frozen hash grouping classes by stereotype
      def self.build_stereotypes(document)
        builder = new(document)
        builder.build_stereotype_index
        builder.instance_variable_get(:@stereotypes).freeze
      end

      # Build inheritance graph index
      #
      # @param document [Lutaml::Uml::Document] The UML document
      # @param indexes [Hash, nil] Existing indexes (requires :qualified_names)
      # @return [Hash] Frozen hash mapping parent qnames to child qnames
      def self.build_inheritance_graph(document, indexes)
        builder = new(document)
        # If qualified_names index is provided, use it
        if indexes && indexes[:qualified_names]
          builder.instance_variable_set(:@qualified_names,
                                        indexes[:qualified_names])
        else
          builder.build_qualified_name_index
        end
        builder.build_inheritance_graph_index
        builder.instance_variable_get(:@inheritance_graph).freeze
      end

      # Build diagram index
      #
      # @param document [Lutaml::Uml::Document] The UML document
      # @param indexes [Hash, nil] Existing indexes (requires :package_paths)
      # @return [Hash] Frozen hash mapping package IDs to Diagram objects
      def self.build_diagram_index(document, indexes)
        builder = new(document)
        # If package_paths index is provided, use it
        if indexes && indexes[:package_paths]
          builder.instance_variable_set(:@package_paths,
                                        indexes[:package_paths])
        else
          builder.build_package_path_index
        end
        builder.build_diagram_index
        builder.instance_variable_get(:@diagram_index).freeze
      end

      def initialize(document)
        @document = document
        @package_paths = {}
        @qualified_names = {}
        @stereotypes = {}
        @inheritance_graph = {}
        @diagram_index = {}
        @package_to_path = {}
        @class_to_qname = {}
        @classes = {}
        @associations = {}
      end

      # Build all indexes and return them as a frozen hash
      #
      # @return [Hash] Frozen hash containing all indexes
      def build_all # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        build_package_path_index
        build_qualified_name_index
        build_stereotype_index
        build_inheritance_graph_index
        build_diagram_index
        build_association_index

        {
          package_paths: @package_paths.freeze,
          qualified_names: @qualified_names.freeze,
          stereotypes: @stereotypes.freeze,
          inheritance_graph: @inheritance_graph.freeze,
          diagram_index: @diagram_index.freeze,
          package_to_path: @package_to_path.freeze,
          class_to_qname: @class_to_qname.freeze,
          classes: @classes.freeze,
          associations: @associations.freeze,
        }.freeze
      end

      # Build the package path index
      #
      # Creates a hash mapping package paths to Package objects:
      #   "ModelRoot" => Package{},
      #   "ModelRoot::i-UR" => Package{},
      #   "ModelRoot::i-UR::urf" => Package{}
      # @api public
      def build_package_path_index
        # Add root package if it exists
        @package_paths[ROOT_PACKAGE_NAME] = @document if @document

        # Traverse all packages recursively
        traverse_packages(@document.packages,
                          parent_path: ROOT_PACKAGE_NAME) do |package, path|
          @package_paths[path] = package
          @package_to_path[package.xmi_id] = path if package.xmi_id
        end
      end

      # Build the qualified name index
      #
      # Creates a hash mapping qualified names to Class/DataType/Enum objects:
      #   "ModelRoot::i-UR::urf::Building" => Class{}
      # @api public
      def build_qualified_name_index # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength
        # Index top-level classes, data_types, and enums from document
        if @document.classes
          index_classifiers(@document.classes,
                            ROOT_PACKAGE_NAME)
        end
        if @document.data_types
          index_classifiers(@document.data_types,
                            ROOT_PACKAGE_NAME)
        end
        index_classifiers(@document.enums, ROOT_PACKAGE_NAME) if @document.enums

        # Traverse packages and index their classifiers
        traverse_packages(@document.packages,
                          parent_path: ROOT_PACKAGE_NAME) do |package, path|
          index_classifiers(package.classes, path) if package.classes
          index_classifiers(package.data_types, path) if package.data_types
          index_classifiers(package.enums, path) if package.enums
        end
      end

      def build_association_index # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        # Collect document-level associations (XMI format)
        @document.associations&.each do |assoc|
          next unless assoc.xmi_id

          @associations[assoc.xmi_id] = assoc
        end

        # Collect class-level associations (QEA/EA format)
        # Note: This requires qualified_names index to be built first
        @qualified_names.each_value do |klass|
          next unless klass.respond_to?(:associations) && klass.associations

          klass.associations.each do |assoc|
            next unless assoc.xmi_id

            # Avoid duplicates - only add if not already present
            @associations[assoc.xmi_id] ||= assoc
          end
        end
      end

      # Build the stereotype index
      #
      # Creates a hash grouping classes by their stereotype:
      #   "featureType" => [Class{}, Class{}],
      #   "dataType" => [Class{}]
      # @api public
      def build_stereotype_index # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity
        # Process top-level classes
        index_by_stereotype(@document.classes) if @document.classes
        index_by_stereotype(@document.data_types) if @document.data_types
        index_by_stereotype(@document.enums) if @document.enums

        # Process classes in packages
        traverse_packages(@document.packages) do |package, _path|
          index_by_stereotype(package.classes) if package.classes
          index_by_stereotype(package.data_types) if package.data_types
          index_by_stereotype(package.enums) if package.enums
        end
      end

      # Build the inheritance graph index
      #
      # Creates a hash mapping parent qualified names to arrays of
      # child qualified names:
      #   "ModelRoot::Parent" => ["ModelRoot::Child1", "ModelRoot::Child2"]
      # @api public
      def build_inheritance_graph_index
        # Process top-level classes
        if @document.classes
          process_generalizations(@document.classes,
                                  ROOT_PACKAGE_NAME)
        end

        # Process classes in packages
        traverse_packages(@document.packages,
                          parent_path: ROOT_PACKAGE_NAME) do |package, path|
          process_generalizations(package.classes, path) if package.classes
        end
      end

      # Build the diagram index
      #
      # Creates a hash mapping package IDs/paths to arrays of Diagram objects:
      #   "package_id" => [Diagram{}, Diagram{}]
      # @api public
      def build_diagram_index
        # Traverse packages and collect diagrams
        traverse_packages(@document.packages) do |package, path|
          next unless package.diagrams && !package.diagrams.empty?

          # Index by package ID if available, otherwise by path
          key = package.xmi_id || path
          @diagram_index[key] ||= []
          @diagram_index[key].concat(package.diagrams)
        end
      end

      # Traverse packages recursively, yielding each package with its path
      #
      # @param packages [Array<Lutaml::Uml::Package>] Packages to traverse
      # @param parent_path [String, nil] Parent package path
      # @yield [package, path] Yields each package with its full path
      def traverse_packages(packages, parent_path: nil, &block)
        return unless packages

        packages.each do |package|
          path = build_package_path(package.name, parent_path)
          yield package, path if block

          # Recursively traverse nested packages
          if package.packages
            traverse_packages(package.packages, parent_path: path,
                              &block)
          end
        end
      end

      # Build a package path from a package name and parent path
      #
      # @param name [String] Package name
      # @param parent_path [String, nil] Parent package path
      # @return [String] Full package path
      def build_package_path(name, parent_path)
        return name unless parent_path

        "#{parent_path}::#{name}"
      end

      # Index classifiers (classes, data types, enums) by their qualified names
      #
      # @param classifiers [Array] Array of classifier objects
      # @param package_path [String] Package path for these classifiers
      def index_classifiers(classifiers, package_path) # rubocop:disable Metrics/MethodLength
        return unless classifiers

        classifiers.each do |classifier|
          next unless classifier.name

          qualified_name = "#{package_path}::#{classifier.name}"
          @qualified_names[qualified_name] = classifier
          if classifier.xmi_id
            @class_to_qname[classifier.xmi_id] =
              qualified_name
          end
          @classes[classifier.xmi_id] = classifier if classifier.xmi_id
        end
      end

      # Index classifiers by their stereotypes
      #
      # @param classifiers [Array] Array of classifier objects
      def index_by_stereotype(classifiers) # rubocop:disable Metrics/CyclomaticComplexity
        return unless classifiers

        classifiers.each do |classifier|
          next unless classifier.stereotype && !classifier.stereotype.empty?

          # Handle both String and Array stereotypes
          stereotypes = Array(classifier.stereotype)
          stereotypes.each do |stereotype|
            @stereotypes[stereotype] ||= []
            @stereotypes[stereotype] << classifier
          end
        end
      end

      # Process generalization relationships to build inheritance graph
      #
      # @param classes [Array<Lutaml::Uml::Class>] Classes to process
      # @param package_path [String] Package path for these classes
      def process_generalizations(classes, package_path) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        return unless classes

        classes.each do |klass|
          next unless klass.name
          next unless klass.generalization

          child_qname = "#{package_path}::#{klass.name}"

          # Handle generalization - it could have a general attribute
          parent_name = extract_parent_name(klass.generalization)
          next unless parent_name

          # Try to resolve parent qualified name
          parent_qname = resolve_qualified_name(parent_name, package_path)
          next unless parent_qname

          # Avoid self-references
          if child_qname != parent_qname
            @inheritance_graph[parent_qname] ||= []
            @inheritance_graph[parent_qname] << child_qname
          end
        end
      end

      # Extract parent name from generalization object
      #
      # @param generalization [Lutaml::Uml::Generalization]
      # Generalization object
      # @return [String, nil] Parent class name
      def extract_parent_name(generalization) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/MethodLength
        return nil unless generalization

        # Check for general attribute (could be a string or object)
        if generalization.respond_to?(:general)
          parent = generalization.general
          return parent.name if parent.respond_to?(:name)
          return parent.to_s if parent
        end

        # Check for name attribute directly
        if generalization.respond_to?(:name) && generalization.name
          return generalization.name
        end

        nil
      end

      # Resolve a class name to its qualified name
      #
      # This is a simplified resolution that checks:
      # 1. Same package
      # 2. Already qualified name in index
      #
      # @param name [String] Class name to resolve
      # @param current_package_path [String] Current package context
      # @return [String, nil] Resolved qualified name
      def resolve_qualified_name(name, current_package_path)
        # If name contains "::", it might already be qualified
        return name if @qualified_names.key?(name)

        # Try in current package
        local_qname = "#{current_package_path}::#{name}"
        return local_qname if @qualified_names.key?(local_qname)

        # Try to find in all qualified names (simple name match)
        @qualified_names.each_key do |qname|
          return qname if qname.end_with?("::#{name}")
        end

        nil
      end
    end
  end
end
