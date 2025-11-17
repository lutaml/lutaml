# frozen_string_literal: true

require_relative "../parser"
require_relative "../uml/package_path"
require_relative "../uml/qualified_name"
require_relative "error_handler"
require_relative "index_builder"
require_relative "statistics_calculator"
require_relative "validators/repository_validator"
require_relative "package_exporter"
require_relative "package_loader"
require_relative "queries/package_query"
require_relative "queries/class_query"
require_relative "queries/inheritance_query"
require_relative "queries/association_query"
require_relative "queries/diagram_query"
require_relative "queries/search_query"
require_relative "query_dsl/query_builder"
# require_relative "lazy_repository"

module Lutaml
  module UmlRepository
    # Repository provides a fully indexed, queryable in-memory representation
    # of a UML model.
    #
    # It wraps the existing [`Lutaml::Uml::Document`](../../uml/document.rb)
    # model and adds:
    # - Package hierarchy with path-based navigation
    # - Class index with qualified name lookups
    # - Type resolution for attribute data types
    # - Association tracking including ownership and navigability
    # - Diagram metadata for visualization
    # - Search capabilities across all model elements
    #
    # Repository can be built from XMI files or loaded from pre-serialized
    # LUR (LutaML UML Repository) packages for instant loading.
    #
    # @example Building from XMI
    #   repo = Lutaml::Xmi::Repository.from_xmi('model.xmi')
    #   klass = repo.find_class("ModelRoot::i-UR::urf::Building")
    #
    # @example Navigating package hierarchy
    #   packages = repo.list_packages("ModelRoot::i-UR", recursive: true)
    #   tree = repo.package_tree("ModelRoot", max_depth: 2)
    #
    # @example Querying inheritance
    #   parent = repo.supertype_of("ModelRoot::Child")
    #   descendants = repo.descendants_of("ModelRoot::Parent", max_depth: 2)
    class Repository
      # @return [Lutaml::Uml::Document] The underlying UML document
      attr_reader :document

      # @return [Hash] The indexes for fast lookups
      attr_reader :indexes

      # Initialize a new Repository.
      #
      # This is typically not called directly. Use [`from_xmi`](#from_xmi) instead.
      #
      # @param document [Lutaml::Uml::Document] The UML document to wrap
      # @param indexes [Hash, nil] Pre-built indexes, or nil to build them
      #   automatically
      # @return [Repository] A new frozen repository instance
      # @example
      #   indexes = IndexBuilder.build_all(document)
      #   repo = Repository.new(document: document, indexes: indexes)
      def initialize(document:, indexes: nil)
        @document = document.freeze
        @indexes = indexes || IndexBuilder.build_all(document)

        # Initialize runtime query services (not serialized to LUR)
        # These are lightweight wrappers that operate on @document and @indexes
        @package_query = Queries::PackageQuery.new(@document, @indexes)
        @class_query = Queries::ClassQuery.new(@document, @indexes)
        @inheritance_query = Queries::InheritanceQuery.new(@document, @indexes)
        @association_query = Queries::AssociationQuery.new(@document, @indexes)
        @diagram_query = Queries::DiagramQuery.new(@document, @indexes)
        @search_query = Queries::SearchQuery.new(@document, @indexes)

        # Initialize statistics calculator and cache result
        @statistics_calculator = StatisticsCalculator.new(@document, @indexes)
        @statistics = @statistics_calculator.calculate.freeze

        # Initialize error handler for helpful error messages
        @error_handler = ErrorHandler.new(self)

        freeze
      end

      # Build a Repository from an XMI file.
      #
      # @param xmi_path [String] Path to the XMI file
      # @param options [Hash] Options for parsing
      # @option options [Boolean] :validate (false) Validate model consistency
      #   after building indexes
      # @return [Repository] A new repository instance
      # @example
      #   repo = Repository.from_xmi('model.xmi')
      #   repo = Repository.from_xmi('model.xmi', validate: true)
      def self.from_xmi(xmi_path, _options = {})
        # Parse XMI using Lutaml::Parser
        document = Lutaml::Parser.parse([File.new(xmi_path)]).first

        # Build indexes
        indexes = IndexBuilder.build_all(document)

        # Optionally validate (placeholder for future validation logic)
        # if options[:validate]
        #   validate_model(document, indexes)
        # end

        new(document: document, indexes: indexes)
      end

      # Build a Repository from an XMI file with lazy index loading.
      #
      # This method creates a LazyRepository that builds indexes on-demand
      # rather than upfront. Useful for very large models (1000+ classes)
      # to reduce initial load time and memory usage.
      #
      # @param xmi_path [String] Path to the XMI file
      # @param options [Hash] Options for parsing
      # @return [LazyRepository] A new lazy repository instance
      # @example
      #   repo = Repository.from_xmi_lazy('large-model.xmi')
      #   # Only document loaded, indexes built on first access
      def self.from_xmi_lazy(xmi_path, _options = {})
        # Parse XMI using Lutaml::Parser
        document = Lutaml::Parser.parse([File.new(xmi_path)]).first

        LazyRepository.new(document: document, lazy: true)
      end

      # Auto-detect file type and load appropriately.
      #
      # Detects whether the file is an XMI file (.xmi) or a LUR package (.lur)
      # and loads it using the appropriate method.
      #
      # @param path [String] Path to the file (.xmi or .lur)
      # @return [Repository] A new or loaded repository instance
      # @raise [ArgumentError] If the file type is unknown
      # @example
      #   repo = Repository.from_file('model.xmi')
      #   repo = Repository.from_file('model.lur')
      def self.from_file(path)
        case File.extname(path).downcase
        when ".xmi" then from_xmi(path)
        when ".lur" then from_package(path)
        else
          raise ArgumentError,
                "Unknown file type: #{path}. Expected .xmi or .lur"
        end
      end

      # Smart caching - use LUR if newer than XMI, otherwise rebuild.
      #
      # This method implements intelligent caching by checking if a LUR package
      # exists and is newer than the source XMI file. If so, it loads from the
      # cache. Otherwise, it builds from XMI and creates/updates the cache.
      #
      # @param xmi_path [String] Path to the XMI file
      # @param lur_path [String, nil] Path to the LUR package (default: XMI path
      #   with .lur extension)
      # @return [Repository] A repository instance
      # @example Using default cache path
      #   repo = Repository.from_file_cached('model.xmi')
      #   # Creates/uses model.lur
      #
      # @example Using custom cache path
      #   repo = Repository.from_file_cached('model.xmi',
      #                                          lur_path: 'cache/model.lur')
      def self.from_file_cached(xmi_path, lur_path: nil)
        lur_path ||= xmi_path.sub(/\.xmi$/i, ".lur")

        if File.exist?(lur_path) && File.mtime(lur_path) >= File.mtime(xmi_path)
          puts "Using cached LUR package: #{lur_path}" if $VERBOSE
          from_package(lur_path)
        else
          puts "Building repository from XMI..." if $VERBOSE
          repo = from_xmi(xmi_path)

          puts "Caching as LUR package: #{lur_path}" if $VERBOSE
          repo.export_to_package(lur_path)
          repo
        end
      end

      # Load a Repository from a LUR package file.
      #
      # @param lur_path [String] Path to the .lur package file
      # @return [Repository] A loaded repository instance
      # @example
      #   repo = Repository.from_package("model.lur")
      def self.from_package(lur_path)
        PackageLoader.load(lur_path)
      end

      # Load a Repository from a LUR package file with lazy loading.
      #
      # This method loads the document without building indexes, deferring
      # index creation until first access. Useful for very large models.
      #
      # @param lur_path [String] Path to the .lur package file
      # @return [LazyRepository] A loaded lazy repository instance
      # @example
      #   repo = Repository.from_package_lazy("large-model.lur")
      def self.from_package_lazy(lur_path)
        PackageLoader.load_document_only(lur_path)
      end

      # Auto-detect file type and load with lazy loading.
      #
      # Detects whether the file is an XMI file (.xmi) or a LUR package (.lur)
      # and loads it using the appropriate lazy loading method.
      #
      # @param path [String] Path to the file (.xmi or .lur)
      # @return [LazyRepository] A new or loaded lazy repository instance
      # @raise [ArgumentError] If the file type is unknown
      # @example
      #   repo = Repository.from_file_lazy('large-model.xmi')
      #   repo = Repository.from_file_lazy('large-model.lur')
      def self.from_file_lazy(path)
        case File.extname(path).downcase
        when ".xmi" then from_xmi_lazy(path)
        when ".lur" then from_package_lazy(path)
        else
          raise ArgumentError,
                "Unknown file type: #{path}. Expected .xmi or .lur"
        end
      end

      # Export this repository to a LUR package file.
      #
      # @param output_path [String] Path for the output .lur file
      # @param options [Hash] Export options
      # @option options [String] :name ("UML Model") Package name
      # @option options [String] :version ("1.0") Package version
      # @option options [Boolean] :include_xmi (false) Include source XMI
      # @option options [Symbol] :serialization_format (:marshal) Format to use
      #   (:marshal or :yaml)
      # @option options [Integer] :compression_level (6) ZIP compression level
      # @return [void]
      # @example Export with defaults
      #   repo.export_to_package("model.lur")
      #
      # @example Export with custom options
      #   repo.export_to_package("model.lur",
      #     name: "My Model",
      #     version: "2.0",
      #     serialization_format: :yaml
      #   )
      def export_to_package(output_path, options = {})
        PackageExporter.new(self, options).export(output_path)
      end

      # Find a package by its path.
      #
      # @param path [String] The package path (e.g., "ModelRoot::i-UR::urf")
      # @param raise_on_error [Boolean] Whether to raise an error if not found
      #   (default: false)
      # @return [Lutaml::Uml::Package, Lutaml::Uml::Document, nil] The package
      #   or document, or nil if not found
      # @raise [NameError] If package not found and raise_on_error is true
      # @example
      #   package = repo.find_package("ModelRoot::i-UR::urf")
      #   package = repo.find_package("ModelRoot::typo", raise_on_error: true)
      def find_package(path, raise_on_error: false)
        result = package_query.find_by_path(path)
        return result if result || !raise_on_error

        @error_handler.package_not_found_error(path)
      end

      # List packages at a specific path.
      #
      # @param path [String] The parent package path (default: "ModelRoot")
      # @param recursive [Boolean] Whether to include nested packages
      #   recursively (default: false)
      # @return [Array<Lutaml::Uml::Package>] Array of packages
      # @example Non-recursive listing
      #   packages = repo.list_packages("ModelRoot::i-UR", recursive: false)
      #
      # @example Recursive listing
      #   packages = repo.list_packages("ModelRoot", recursive: true)
      def list_packages(path = "ModelRoot", recursive: false)
        package_query.list(path, recursive: recursive)
      end

      # Build a hierarchical tree structure of packages.
      #
      # @param path [String] The root package path to start from
      #   (default: "ModelRoot")
      # @param max_depth [Integer, nil] Maximum depth to traverse (nil for
      #   unlimited)
      # @return [Hash, nil] Tree structure with package information, or nil
      #   if root not found
      # @example
      #   tree = repo.package_tree("ModelRoot::i-UR", max_depth: 2)
      def package_tree(path = "ModelRoot", max_depth: nil)
        package_query.tree(path, max_depth: max_depth)
      end

      # Find a class by its qualified name.
      #
      # @param qualified_name [String] The qualified name
      #   (e.g., "ModelRoot::i-UR::urf::Building")
      # @param raise_on_error [Boolean] Whether to raise an error if not found
      #   (default: false)
      # @return [Lutaml::Uml::Class, Lutaml::Uml::DataType, Lutaml::Uml::Enum, nil]
      #   The class object, or nil if not found
      # @raise [NameError] If class not found and raise_on_error is true
      # @example
      #   klass = repo.find_class("ModelRoot::i-UR::urf::Building")
      #   klass = repo.find_class("ModelRoot::Typo", raise_on_error: true)
      def find_class(qualified_name, raise_on_error: false)
        result = class_query.find_by_qname(qualified_name)
        return result if result || !raise_on_error

        @error_handler.class_not_found_error(qualified_name)
      end

      # Find all classes with a specific stereotype.
      #
      # @param stereotype [String] The stereotype to search for
      # @return [Array] Array of class objects with the stereotype
      # @example
      #   feature_types = repo.find_classes_by_stereotype("featureType")
      def find_classes_by_stereotype(stereotype)
        class_query.find_by_stereotype(stereotype)
      end

      # Get classes in a specific package.
      #
      # @param package_path [String] The package path
      # @param recursive [Boolean] Whether to include classes from nested
      #   packages (default: false)
      # @return [Array] Array of class objects in the package
      # @example
      #   classes = repo.classes_in_package("ModelRoot::i-UR::urf")
      #   all_classes = repo.classes_in_package("ModelRoot::i-UR", recursive: true)
      def classes_in_package(package_path, recursive: false)
        class_query.in_package(package_path, recursive: recursive)
      end

      # Get the direct parent class (supertype).
      #
      # @param class_or_qname [Lutaml::Uml::Class, String] The class object
      #   or qualified name string
      # @return [Lutaml::Uml::Class, nil] The parent class, or nil if no parent
      # @example
      #   parent = repo.supertype_of("ModelRoot::Child")
      #   parent = repo.supertype_of(child_class)
      def supertype_of(class_or_qname)
        inheritance_query.supertype(class_or_qname)
      end

      # Get direct child classes (subtypes).
      #
      # @param class_or_qname [Lutaml::Uml::Class, String] The class object
      #   or qualified name string
      # @param recursive [Boolean] Whether to include all descendants
      #   (default: false)
      # @return [Array] Array of child class objects
      # @example
      #   children = repo.subtypes_of("ModelRoot::Parent")
      #   all_descendants = repo.subtypes_of("ModelRoot::Parent", recursive: true)
      def subtypes_of(class_or_qname, recursive: false)
        inheritance_query.subtypes(class_or_qname, recursive: recursive)
      end

      # Get all ancestor classes up to the root.
      #
      # Returns ancestors in order from immediate parent to root.
      #
      # @param class_or_qname [Lutaml::Uml::Class, String] The class object
      #   or qualified name string
      # @return [Array] Array of ancestor class objects, ordered from nearest
      #   to furthest
      # @example
      #   ancestors = repo.ancestors_of("ModelRoot::GrandChild")
      def ancestors_of(class_or_qname)
        inheritance_query.ancestors(class_or_qname)
      end

      # Get all descendant classes.
      #
      # @param class_or_qname [Lutaml::Uml::Class, String] The class object
      #   or qualified name string
      # @param max_depth [Integer, nil] Maximum depth to traverse (nil for
      #   unlimited)
      # @return [Array] Array of descendant class objects
      # @example
      #   descendants = repo.descendants_of("ModelRoot::Parent", max_depth: 2)
      def descendants_of(class_or_qname, max_depth: nil)
        inheritance_query.descendants(class_or_qname, max_depth: max_depth)
      end

      # Get associations involving a class.
      #
      # @param class_or_qname [Lutaml::Uml::Class, String] The class object
      #   or qualified name string
      # @param options [Hash] Query options
      # @option options [Symbol] :direction (:both) Filter by direction:
      #   :source, :target, or :both
      # @option options [Boolean] :owned_only Return only owned associations
      # @option options [Boolean] :navigable_only Return only navigable associations
      # @return [Array<Lutaml::Uml::Association>] Array of association objects
      # @example
      #   all_assocs = repo.associations_of("ModelRoot::Building")
      #   outgoing = repo.associations_of("ModelRoot::Building", direction: :source)
      def associations_of(class_or_qname, options = {})
        association_query.find_for_class(class_or_qname, options)
      end

      # Get diagrams in a specific package.
      #
      # @param package_path [String] The package path or package ID
      # @return [Array<Lutaml::Uml::Diagram>] Array of diagram objects
      # @example
      #   diagrams = repo.diagrams_in_package("ModelRoot::i-UR::urf")
      def diagrams_in_package(package_path)
        diagram_query.in_package(package_path)
      end

      # Find a diagram by its name.
      #
      # @param diagram_name [String] The diagram name
      # @return [Lutaml::Uml::Diagram, nil] The diagram object, or nil if not found
      # @example
      #   diagram = repo.find_diagram("Class Diagram 1")
      def find_diagram(diagram_name)
        diagram_query.find_by_name(diagram_name)
      end

      # Get all diagrams in the model.
      #
      # @return [Array<Lutaml::Uml::Diagram>] Array of all diagram objects
      # @example
      #   all_diagrams = repo.all_diagrams
      def all_diagrams
        diagram_query.all
      end

      # Search for model elements by query string.
      #
      # @param query [String] The search query
      # @param types [Array<Symbol>] Types to search (:class, :attribute,
      #   :association) (default: [:class, :attribute, :association])
      # @param fields [Array<Symbol>] Fields to search in (:name, :documentation)
      #   (default: [:name])
      # @return [Hash] Search results grouped by type
      # @example
      #   results = repo.search("Building")
      #   results = repo.search("address", types: [:attribute])
      #   results = repo.search("urban", fields: [:name, :documentation])
      def search(query, types: %i[class attribute association],
fields: [:name])
        search_query.search(query, types: types, fields: fields)
      end

      # Search for model elements by regex pattern.
      #
      # Similar to search but treats query as a regex pattern. Returns
      # SearchResult objects for consistency with regular search.
      #
      # @param pattern [String, Regexp] The regex pattern to match
      # @param types [Array<Symbol>] Types to search (:class, :attribute,
      #   :association) (default: [:class, :attribute, :association])
      # @param fields [Array<Symbol>] Fields to search in (:name, :documentation)
      #   (default: [:name])
      # @return [Hash] Search results grouped by type (same format as search)
      # @example
      #   results = repo.search_by_pattern("^Building.*", types:[:class])
      #   results = repo.search_by_pattern(/address$/i, types: [:attribute])
      #   results = repo.search_by_pattern("urban", fields: [:documentation])
      def search_by_pattern(pattern, types: %i[class attribute association],
fields: [:name])
        search_query.search_by_pattern(pattern, types: types, fields: fields)
      end

      # Find model elements by pattern.
      #
      # @param pattern [String, Regexp] The pattern to match
      # @param type [Symbol] Type to search (:class, :attribute, :association)
      #   (default: :class)
      # @return [Array] Array of matching elements
      # @example
      #   classes = repo.find_by_pattern(/^Building/, type: :class)
      #   attrs = repo.find_by_pattern("address", type: :attribute)
      def find_by_pattern(pattern, type: :class)
        search_query.by_pattern(pattern, type: type)
      end

      # Get comprehensive statistics about the repository.
      #
      # Returns detailed metrics including package depths, class complexity,
      # attribute distributions, and model quality metrics.
      # Statistics are calculated once during initialization and cached.
      #
      # @return [Hash] Comprehensive statistics hash
      # @example
      #   stats = repo.statistics
      #   puts "Total packages: #{stats[:total_packages]}"
      #   puts "Max package depth: #{stats[:max_package_depth]}"
      #   puts "Most complex class: #{stats[:most_complex_classes].first[:name]}"
      def statistics
        @statistics
      end

      # Validate the repository for consistency and integrity.
      #
      # Performs comprehensive validation including:
      # - Type reference validation
      # - Generalization reference validation
      # - Circular inheritance detection
      # - Association reference validation
      # - Multiplicity validation
      #
      # @return [Validators::ValidationResult] Validation results
      # @example
      #   result = repo.validate
      #   if result.valid?
      #     puts "Repository is valid"
      #   else
      #     result.errors.each { |error| puts "ERROR: #{error}" }
      #   end
      def validate
        Validators::RepositoryValidator.new(@document, @indexes).validate
      end

      # Build a query using the Query DSL
      #
      # Provides a fluent interface for building complex queries with
      # method chaining, lazy evaluation, and composable filters.
      #
      # @yield [QueryDSL::QueryBuilder] The query builder
      # @return [QueryDSL::QueryBuilder] The query builder for further chaining
      # @example Basic query
      #   results = repo.query do |q|
      #     q.classes.where(stereotype: 'featureType')
      #   end.all
      #
      # @example Complex query
      #   results = repo.query do |q|
      #     q.classes
      #       .in_package('ModelRoot::i-UR', recursive: true)
      #       .where { |c| c.attributes&.size.to_i > 10 }
      #       .order_by(:name, direction: :desc)
      #       .limit(5)
      #   end.execute
      def query(&block)
        builder = QueryDSL::QueryBuilder.new(self)
        block&.call(builder)
        builder
      end

      # Build and execute a query using the Query DSL
      #
      # Same as [`query`](#query) but executes immediately and returns results.
      #
      # @yield [QueryDSL::QueryBuilder] The query builder
      # @return [Array] The query results
      # @example
      #   results = repo.query! do |q|
      #     q.classes.where(stereotype: 'featureType')
      #   end
      def query!(&block)
        query(&block).execute
      end

      # Convenience methods for SPA data transformer

      # Get all packages as an array (excluding root Document)
      # @return [Array<Lutaml::Uml::Package>] All packages
      def packages_index
        (@indexes[:package_paths]&.values || []).select { |p| p.is_a?(Lutaml::Uml::Package) }
      end

      # Get all classes (including datatypes and enums) as an array
      # @return [Array] All classifiers
      def classes_index
        @indexes[:qualified_names]&.values || []
      end

      # Get all associations as an array
      # @return [Array<Lutaml::Uml::Association>] All associations
      def associations_index
        @document.associations || []
      end

      # Get all diagrams as an array
      # @return [Array<Lutaml::Uml::Diagram>] All diagrams
      def diagrams_index
        all_diagrams
      end

      # DEPRECATED: Use search with types: [:class] instead
      # @deprecated Use {#search} with types filter
      def search_classes(query_string)
        search(query_string, types: [:class])[:classes]
      end

      # DEPRECATED: Use subtypes_of instead
      # @deprecated Use {#subtypes_of}
      def find_children(class_or_qname, recursive: false)
        subtypes_of(class_or_qname, recursive: recursive)
      end

      # DEPRECATED: Use associations_of instead
      # @deprecated Use {#associations_of}
      def find_associations(class_or_qname, options = {})
        associations_of(class_or_qname, options)
      end

      # DEPRECATED: Use diagrams_in_package or all_diagrams instead
      # @deprecated Use {#diagrams_in_package} or {#all_diagrams}
      def find_diagrams(package_path)
        diagrams_in_package(package_path)
      end

      # DEPRECATED: Use export_to_package instead
      # @deprecated Use {#export_to_package}
      def export(output_path, options = {})
        export_to_package(output_path, options)
      end

      # Custom marshaling to exclude runtime-only query objects
      #
      # Only serializes the core data (document and indexes), not the
      # derived query service objects. This keeps serialized size minimal.
      #
      # @return [Hash] Serializable state (document and indexes only)
      # @api private
      def marshal_dump
        { document: @document, indexes: @indexes }
      end

      # Restore from marshaled state
      #
      # Reconstructs the repository from serialized document and indexes,
      # reinitializing all query services.
      #
      # @param data [Hash] Serialized state with :document and :indexes
      # @return [void]
      # @api private
      def marshal_load(data)
        @document = data[:document]
        @indexes = data[:indexes]

        # Reinitialize runtime query services
        @package_query = Queries::PackageQuery.new(@document, @indexes)
        @class_query = Queries::ClassQuery.new(@document, @indexes)
        @inheritance_query = Queries::InheritanceQuery.new(@document, @indexes)
        @association_query = Queries::AssociationQuery.new(@document, @indexes)
        @diagram_query = Queries::DiagramQuery.new(@document, @indexes)
        @search_query = Queries::SearchQuery.new(@document, @indexes)

        # Reinitialize helpers and cache statistics
        @statistics_calculator = StatisticsCalculator.new(@document, @indexes)
        @statistics = @statistics_calculator.calculate.freeze
        @error_handler = ErrorHandler.new(self)

        freeze
      end

      private

      # Get package query service
      #
      # @return [Queries::PackageQuery] The package query service
      attr_reader :package_query

      # Get class query service
      #
      # @return [Queries::ClassQuery] The class query service
      attr_reader :class_query

      # Get inheritance query service
      #
      # @return [Queries::InheritanceQuery] The inheritance query service
      attr_reader :inheritance_query

      # Get association query service
      #
      # @return [Queries::AssociationQuery] The association query service
      attr_reader :association_query

      # Get diagram query service
      #
      # @return [Queries::DiagramQuery] The diagram query service
      attr_reader :diagram_query

      # Get search query service
      #
      # @return [Queries::SearchQuery] The search query service
      attr_reader :search_query
    end
  end
end
