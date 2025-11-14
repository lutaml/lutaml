# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module QueryDSL
      # Order specification for sorting query results
      #
      # Sorts results based on a specified field and direction.
      # Handles nil values by treating them as empty strings for comparison.
      #
      # @example Ascending order
      #   order = Order.new(:name, :asc)
      #   sorted = order.apply(classes)
      #
      # @example Descending order
      #   order = Order.new(:name, :desc)
      #   sorted = order.apply(classes)
      class Order
        VALID_DIRECTIONS = %i[asc desc].freeze

        attr_reader :field, :direction

        # Initialize with field and direction
        #
        # @param field [Symbol, String] The field to sort by
        # @param direction [Symbol] The sort direction (:asc or :desc)
        # @raise [ArgumentError] if direction is invalid
        def initialize(field, direction = :asc)
          @field = field.to_sym
          @direction = validate_direction(direction)
        end

        # Apply ordering to results
        #
        # @param results [Array] The collection to sort
        # @return [Array] The sorted collection
        def apply(results)
          sorted = results.sort_by do |obj|
            extract_sort_value(obj)
          end

          @direction == :desc ? sorted.reverse : sorted
        end

        private

        # Validate sort direction
        #
        # @param direction [Symbol] The direction to validate
        # @return [Symbol] The validated direction
        # @raise [ArgumentError] if direction is invalid
        def validate_direction(direction)
          dir = direction.to_sym
          unless VALID_DIRECTIONS.include?(dir)
            raise ArgumentError,
                  "Invalid direction: #{direction}. " \
                  "Must be one of #{VALID_DIRECTIONS.join(', ')}"
          end
          dir
        end

        # Extract sort value from object
        #
        # @param obj [Object] The object to extract value from
        # @return [Object] The value to use for sorting
        def extract_sort_value(obj)
          return "" unless obj.respond_to?(@field)

          value = obj.send(@field)
          normalize_value(value)
        end

        # Normalize value for sorting
        #
        # @param value [Object] The value to normalize
        # @return [Object] The normalized value
        def normalize_value(value)
          case value
          when nil
            ""
          when String
            value.downcase
          else
            value
          end
        end
      end
    end
  end
end
