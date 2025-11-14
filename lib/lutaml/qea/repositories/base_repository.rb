# frozen_string_literal: true

module Lutaml
  module Qea
    module Repositories
      # Base repository for querying model collections
      #
      # This class provides common query methods for all model repositories.
      # Subclasses can extend with model-specific query methods.
      #
      # @example Using base repository
      #   repository = BaseRepository.new(records)
      #   all_records = repository.all
      #   record = repository.find(123)
      #   filtered = repository.where { |r| r.name == "Test" }
      class BaseRepository
        include Enumerable

        # @return [Array] The collection of records
        attr_reader :records

        # Initialize repository with a collection
        #
        # @param records [Array] Array of model instances
        def initialize(records)
          @records = records.freeze
        end

        # Iterates over all records
        #
        # @yield [record] Each record in the collection
        # @return [Enumerator] if no block given
        def each(&block)
          return to_enum(:each) unless block

          @records.each(&block)
        end

        # Get all records
        #
        # @return [Array] All records in the collection
        def all
          @records
        end

        # Find a record by primary key
        #
        # @param id [Object] Primary key value
        # @return [Object, nil] The record or nil if not found
        def find(id)
          @records.find { |record| record.primary_key == id }
        end

        # Filter records by conditions
        #
        # @param conditions [Hash] Hash of attribute/value pairs
        # @yield [record] Optional block for custom filtering
        # @yieldparam record [Object] Each record
        # @yieldreturn [Boolean] true to include record
        # @return [Array] Filtered records
        #
        # @example Hash conditions
        #   repository.where(name: "Test", type: "Class")
        #
        # @example Block condition
        #   repository.where { |r| r.name.start_with?("Test") }
        def where(conditions = nil, &block)
          if block
            @records.select(&block)
          elsif conditions.is_a?(Hash)
            @records.select do |record|
              conditions.all? do |attr, value|
                record.respond_to?(attr) && record.send(attr) == value
              end
            end
          else
            @records
          end
        end

        # Count records
        #
        # @param conditions [Hash, nil] Optional conditions to filter
        # @yield [record] Optional block for custom filtering
        # @return [Integer] Number of records
        #
        # @example Count all
        #   repository.count
        #
        # @example Count with conditions
        #   repository.count(type: "Class")
        #
        # @example Count with block
        #   repository.count { |r| r.name.include?("Test") }
        def count(conditions = nil, &block)
          if block || conditions
            where(conditions, &block).size
          else
            @records.size
          end
        end

        # Find first record matching conditions
        #
        # @param conditions [Hash, nil] Optional conditions
        # @yield [record] Optional block for custom filtering
        # @return [Object, nil] First matching record or nil
        #
        # @example
        #   repository.find_first(name: "Test")
        #   repository.find_first { |r| r.name.start_with?("Test") }
        def find_first(conditions = nil, &block)
          where(conditions, &block).first
        end

        # Check if any records match conditions
        #
        # @param conditions [Hash, nil] Optional conditions
        # @yield [record] Optional block for custom filtering
        # @return [Boolean] true if any records match
        def any?(conditions = nil, &block)
          !where(conditions, &block).empty?
        end

        # Check if no records match conditions
        #
        # @param conditions [Hash, nil] Optional conditions
        # @yield [record] Optional block for custom filtering
        # @return [Boolean] true if no records match
        def none?(conditions = nil, &block)
          where(conditions, &block).empty?
        end

        # Select specific attributes from records
        #
        # @param attributes [Array<Symbol>] Attribute names to select
        # @return [Array<Hash>] Array of hashes with selected attributes
        #
        # @example
        #   repository.pluck(:id, :name)
        #   # => [{id: 1, name: "Test"}, {id: 2, name: "Other"}]
        def pluck(*attributes)
          @records.map do |record|
            attributes.each_with_object({}) do |attr, hash|
              hash[attr] = record.send(attr) if record.respond_to?(attr)
            end
          end
        end

        # Group records by an attribute
        #
        # @param attribute [Symbol] Attribute name to group by
        # @return [Hash] Hash with attribute values as keys, arrays as values
        #
        # @example
        #   repository.group_by(:type)
        #   # => {"Class" => [obj1, obj2], "Interface" => [obj3]}
        def group_by(attribute)
          @records.group_by { |record| record.send(attribute) }
        end

        # Sort records by an attribute
        #
        # @param attribute [Symbol] Attribute name to sort by
        # @param order [Symbol] :asc or :desc (default: :asc)
        # @return [Array] Sorted records
        #
        # @example
        #   repository.order_by(:name)
        #   repository.order_by(:created_at, :desc)
        def order_by(attribute, order = :asc)
          sorted = @records.sort_by { |record| record.send(attribute) }
          order == :desc ? sorted.reverse : sorted
        end

        # Get unique values for an attribute
        #
        # @param attribute [Symbol] Attribute name
        # @return [Array] Unique values
        #
        # @example
        #   repository.distinct(:type)
        #   # => ["Class", "Interface", "Component"]
        def distinct(attribute)
          @records.map { |record| record.send(attribute) }.uniq
        end

        # Check if repository is empty
        #
        # @return [Boolean] true if no records
        def empty?
          @records.empty?
        end

        # Get the size of the collection
        #
        # @return [Integer] Number of records
        def size
          @records.size
        end

        alias length size
      end
    end
  end
end
