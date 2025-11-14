# frozen_string_literal: true

require_relative "conditions/base_condition"
require_relative "conditions/hash_condition"
require_relative "conditions/block_condition"
require_relative "conditions/package_condition"
require_relative "order"

module Lutaml
  module UmlRepository
    module QueryDSL
      # Fluent query builder for advanced queries against UML repositories
      #
      # Provides a domain-specific language for building complex queries
      # with method chaining, lazy evaluation, and composable filters.
      #
      # @example Basic class query
      #   results = repo.query do |q|
      #     q.classes.where(stereotype: 'featureType')
      #   end.all
      #
      # @example Complex query with chaining
      #   results = repo.query do |q|
      #     q.classes
      #       .in_package('ModelRoot::i-UR', recursive: true)
      #       .where { |c| c.attributes&.size.to_i > 10 }
      #       .order_by(:name, direction: :desc)
      #       .limit(5)
      #   end.execute
      class QueryBuilder
        # Initialize a new query builder
        #
        # @param repository [UmlRepository] The repository to query against
        def initialize(repository)
          @repository = repository
          @conditions = []
          @scope = nil
          @order = nil
          @limit = nil
          @includes = []
        end

        # Start a class query
        #
        # @return [QueryBuilder] Self for method chaining
        # @example
        #   builder.classes.where(stereotype: 'featureType')
        def classes
          @scope = :classes
          self
        end

        # Start a package query
        #
        # @return [QueryBuilder] Self for method chaining
        # @example
        #   builder.packages.in_package('ModelRoot')
        def packages
          @scope = :packages
          self
        end

        # Add a condition to the query
        #
        # Supports both hash-based and block-based conditions.
        #
        # @param conditions [Hash, nil] Hash of attribute-value pairs to match
        # @param block [Proc] Block for custom filtering logic
        # @return [QueryBuilder] Self for method chaining
        # @example Hash condition
        #   builder.where(stereotype: 'featureType')
        #
        # @example Block condition
        #   builder.where { |c| c.attributes.size > 10 }
        #
        # @example Regex matching
        #   builder.where(name: /^Building/)
        def where(conditions = nil, &block)
          if conditions
            @conditions << Conditions::HashCondition.new(conditions)
          elsif block
            @conditions << Conditions::BlockCondition.new(&block)
          end
          self
        end

        # Filter by stereotype
        #
        # @param stereotype [String] The stereotype to filter by
        # @return [QueryBuilder] Self for method chaining
        # @example
        #   builder.with_stereotype('featureType')
        def with_stereotype(stereotype)
          where(stereotype: stereotype)
        end

        # Filter by package membership
        #
        # @param package_path [String, PackagePath] The package path
        # @param recursive [Boolean] Include descendants (default: false)
        # @return [QueryBuilder] Self for method chaining
        # @example Non-recursive
        #   builder.in_package('ModelRoot::i-UR')
        #
        # @example Recursive
        #   builder.in_package('ModelRoot::i-UR', recursive: true)
        def in_package(package_path, recursive: false)
          @conditions << Conditions::PackageCondition.new(package_path,
                                                          recursive: recursive)
          self
        end

        # Order results by a field
        #
        # @param field [Symbol, String] The field to order by
        # @param direction [Symbol] The direction (:asc or :desc)
        # @return [QueryBuilder] Self for method chaining
        # @example Ascending
        #   builder.order_by(:name)
        #
        # @example Descending
        #   builder.order_by(:name, direction: :desc)
        def order_by(field, direction: :asc)
          @order = Order.new(field, direction)
          self
        end

        # Limit the number of results
        #
        # @param count [Integer] Maximum number of results
        # @return [QueryBuilder] Self for method chaining
        # @example
        #   builder.limit(10)
        def limit(count)
          @limit = count
          self
        end

        # Specify related data to include (placeholder for future enhancement)
        #
        # @param relations [Array<Symbol>] Relations to eager load
        # @return [QueryBuilder] Self for method chaining
        # @example
        #   builder.includes(:attributes, :associations)
        def includes(*relations)
          @includes.concat(relations)
          self
        end

        # Execute the query and return all results
        #
        # @return [Array] The query results
        # @example
        #   results = builder.classes.where(stereotype: 'featureType').execute
        def execute
          results = fetch_base_results
          results = apply_conditions(results)
          results = apply_order(results) if @order
          results = apply_limit(results) if @limit
          results = apply_includes(results) if @includes.any?
          results
        end

        # Alias for execute
        #
        # @return [Array] The query results
        # @example
        #   results = builder.classes.all
        def all
          execute
        end

        # Get the first result
        #
        # @return [Object, nil] The first result or nil if none
        # @example
        #   first_class = builder.classes.with_stereotype('featureType').first
        def first
          limit(1).execute.first
        end

        # Get the last result
        #
        # @return [Object, nil] The last result or nil if none
        # @example
        #   last_class = builder.classes.order_by(:name).last
        def last
          execute.last
        end

        # Count the number of results
        #
        # @return [Integer] The count of matching results
        # @example
        #   count = builder.classes.with_stereotype('featureType').count
        def count
          execute.size
        end

        # Check if any results exist
        #
        # @return [Boolean] true if results exist, false otherwise
        # @example
        #   has_results = builder.classes.with_stereotype('featureType').any?
        def any?
          execute.any?
        end

        # Check if no results exist
        #
        # @return [Boolean] true if no results exist, false otherwise
        # @example
        #   is_empty = builder.classes.with_stereotype('nonexistent').empty?
        def empty?
          execute.empty?
        end

        private

        # Fetch base results based on scope
        #
        # @return [Array] Base collection to filter
        # @raise [RuntimeError] if no scope specified
        def fetch_base_results
          case @scope
          when :classes
            fetch_classes
          when :packages
            fetch_packages
          else
            raise "No scope specified. Use .classes or .packages"
          end
        end

        # Fetch all classes from the repository
        #
        # @return [Array<Lutaml::Uml::Class>] Array of class objects
        def fetch_classes
          indexes = @repository.instance_variable_get(:@indexes)
          qnames_index = indexes[:qualified_names] || {}

          qnames_index.values.select do |obj|
            obj.is_a?(Lutaml::Uml::Class) ||
              obj.is_a?(Lutaml::Uml::DataType) ||
              obj.is_a?(Lutaml::Uml::Enum)
          end
        end

        # Fetch all packages from the repository
        #
        # @return [Array<Lutaml::Uml::Package>] Array of package objects
        def fetch_packages
          indexes = @repository.instance_variable_get(:@indexes)
          package_paths_index = indexes[:package_paths] || {}
          package_paths_index.values
        end

        # Apply all conditions to results
        #
        # @param results [Array] The collection to filter
        # @return [Array] The filtered collection
        def apply_conditions(results)
          @conditions.each do |condition|
            results = condition.apply(results)
          end
          results
        end

        # Apply ordering to results
        #
        # @param results [Array] The collection to sort
        # @return [Array] The sorted collection
        def apply_order(results)
          @order.apply(results)
        end

        # Apply limit to results
        #
        # @param results [Array] The collection to limit
        # @return [Array] The limited collection
        def apply_limit(results)
          results.first(@limit)
        end

        # Apply includes (placeholder for future enhancement)
        #
        # @param results [Array] The collection to enhance
        # @return [Array] The enhanced collection
        def apply_includes(results)
          # Future: Eager load associations, attributes, etc.
          results
        end
      end
    end
  end
end
