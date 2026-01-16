# frozen_string_literal: true

require_relative "repository"

module Lutaml
  module UmlRepository
    # LazyRepository provides lazy loading optimization for very large
    # UML models
    #
    # For extremely large models (1000+ classes), LazyRepository optimizes
    # memory usage and initial load time by building indexes on-demand rather
    # than upfront. Indexes are built only when first accessed, reducing the
    # initial load time significantly.
    #
    # @example Using lazy loading from XMI
    #   repo = Lutaml::Xmi::Repository.from_xmi_lazy('large-model.xmi')
    #   # Only metadata loaded at this point
    #
    #   klass = repo.find_class("ModelRoot::MyClass")
    #   # Now qualified_names index is built
    #
    # @example Building all indexes manually
    #   repo = Lutaml::Xmi::Repository.from_xmi_lazy('model.xmi')
    #   repo.build_all_indexes
    #   # All indexes are now available
    class LazyRepository < Repository
      # Initialize a new LazyRepository with lazy index building.
      #
      # @param document [Lutaml::Uml::Document] The UML document to wrap
      # @param indexes [Hash, nil] Pre-built indexes, or nil to build lazily
      # @param lazy [Boolean] Whether to enable lazy loading (default: true)
      # @return [LazyRepository] A new repository instance (not frozen)
      def initialize(document:, indexes: nil, lazy: true) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        @document = document
        @indexes = indexes || {}
        @lazy_mode = lazy
        @index_builders_pending = Set.new(%i[
                                            package_paths
                                            qualified_names
                                            stereotypes
                                            inheritance_graph
                                            diagram_index
                                          ])

        # Initialize runtime query services (not serialized to LUR)
        # These are lightweight wrappers that operate on @document and @indexes
        @package_query = Queries::PackageQuery.new(@document, @indexes)
        @class_query = Queries::ClassQuery.new(@document, @indexes)
        @inheritance_query = Queries::InheritanceQuery.new(@document, @indexes)
        @association_query = Queries::AssociationQuery.new(@document, @indexes)
        @diagram_query = Queries::DiagramQuery.new(@document, @indexes)
        @search_query = Queries::SearchQuery.new(@document, @indexes)

        # Initialize statistics calculator (lazily computed)
        @statistics_calculator = StatisticsCalculator.new(@document, @indexes)

        # Initialize error handler for helpful error messages
        @error_handler = ErrorHandler.new(self)

        # Don't freeze - we build indexes on demand
      end

      # Find a class by its qualified name.
      #
      # Ensures the qualified_names index is built before querying.
      #
      # @param qualified_name [String] The qualified name
      # @param raise_on_error [Boolean] Whether to raise an error if not found
      # @return [Lutaml::Uml::Class, Lutaml::Uml::DataType,
      # Lutaml::Uml::Enum, nil]
      def find_class(qualified_name, raise_on_error: false)
        ensure_index(:qualified_names)
        super
      end

      # Find a package by its path.
      #
      # Ensures the package_paths index is built before querying.
      #
      # @param path [String] The package path
      # @param raise_on_error [Boolean] Whether to raise an error if not found
      # @return [Lutaml::Uml::Package, Lutaml::Uml::Document, nil]
      def find_package(path, raise_on_error: false)
        ensure_index(:package_paths)
        super
      end

      # Find all classes with a specific stereotype.
      #
      # Ensures the stereotypes index is built before querying.
      #
      # @param stereotype [String] The stereotype to search for
      # @return [Array] Array of class objects with the stereotype
      def find_classes_by_stereotype(stereotype)
        ensure_index(:stereotypes)
        super
      end

      # Get the direct parent class (supertype).
      #
      # Ensures the qualified_names and inheritance_graph indexes are built.
      #
      # @param class_or_qname [Lutaml::Uml::Class, String] The class object
      #   or qualified name string
      # @return [Lutaml::Uml::Class, nil] The parent class, or nil if no parent
      def supertype_of(class_or_qname)
        ensure_index(:qualified_names)
        ensure_index(:inheritance_graph)
        super
      end

      # Get direct child classes (subtypes).
      #
      # Ensures the inheritance_graph index is built before querying.
      #
      # @param class_or_qname [Lutaml::Uml::Class, String] The class object
      #   or qualified name string
      # @param recursive [Boolean] Whether to include all descendants
      # @return [Array] Array of child class objects
      def subtypes_of(class_or_qname, recursive: false)
        ensure_index(:inheritance_graph)
        super
      end

      # Get all ancestor classes up to the root.
      #
      # Ensures the qualified_names and inheritance_graph indexes are built.
      #
      # @param class_or_qname [Lutaml::Uml::Class, String] The class object
      #   or qualified name string
      # @return [Array] Array of ancestor class objects
      def ancestors_of(class_or_qname)
        ensure_index(:qualified_names)
        ensure_index(:inheritance_graph)
        super
      end

      # Get all descendant classes.
      #
      # Ensures the inheritance_graph index is built before querying.
      #
      # @param class_or_qname [Lutaml::Uml::Class, String] The class object
      #   or qualified name string
      # @param max_depth [Integer, nil] Maximum depth to traverse
      # @return [Array] Array of descendant class objects
      def descendants_of(class_or_qname, max_depth: nil)
        ensure_index(:inheritance_graph)
        super
      end

      # Get diagrams in a specific package.
      #
      # Ensures the diagram_index is built before querying.
      #
      # @param package_path [String] The package path or package ID
      # @return [Array<Lutaml::Uml::Diagram>] Array of diagram objects
      def diagrams_in_package(package_path)
        ensure_index(:diagram_index)
        super
      end

      # Manually build all remaining indexes.
      #
      # This method can be called to force building all indexes at once,
      # rather than waiting for them to be built on-demand.
      #
      # @return [LazyRepository] Returns self for method chaining
      # @example
      #   repo = Repository.from_xmi_lazy('model.xmi')
      #   repo.build_all_indexes
      #   # All indexes are now built
      def build_all_indexes
        @index_builders_pending.each { |index_name| ensure_index(index_name) }
        self
      end

      # Check if an index is built.
      #
      # @param index_name [Symbol] The name of the index to check
      # @return [Boolean] True if the index is built, false otherwise
      # @example
      #   repo.index_built?(:qualified_names)  # => false
      #   repo.find_class("ModelRoot::MyClass")
      #   repo.index_built?(:qualified_names)  # => true
      def index_built?(index_name)
        @indexes.key?(index_name) && !@indexes[index_name].nil?
      end

      # Get list of pending indexes.
      #
      # Returns the names of indexes that have not yet been built.
      #
      # @return [Array<Symbol>] Array of pending index names
      # @example
      #   repo.pending_indexes  # => [:package_paths, :qualified_names, ...]
      def pending_indexes
        @index_builders_pending.to_a
      end

      private

      # Ensure an index is built.
      #
      # If the index is already built, this method returns immediately.
      # Otherwise, it builds the index and removes it from the pending list.
      #
      # @param index_name [Symbol] The name of the index to ensure
      # @return [void]
      def ensure_index(index_name) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength
        return if index_built?(index_name)

        puts "Building #{index_name} index..." if $VERBOSE

        case index_name
        when :package_paths
          @indexes[:package_paths] = IndexBuilder.build_package_paths(@document)
        when :qualified_names
          @indexes[:qualified_names] =
            IndexBuilder.build_qualified_names(@document)
        when :stereotypes
          @indexes[:stereotypes] = IndexBuilder.build_stereotypes(@document)
        when :inheritance_graph
          # Requires qualified_names first
          ensure_index(:qualified_names)
          @indexes[:inheritance_graph] =
            IndexBuilder.build_inheritance_graph(@document, @indexes)
        when :diagram_index
          # Requires package_paths first
          ensure_index(:package_paths)
          @indexes[:diagram_index] =
            IndexBuilder.build_diagram_index(@document, @indexes)
        end

        @index_builders_pending.delete(index_name)
      end
    end
  end
end
