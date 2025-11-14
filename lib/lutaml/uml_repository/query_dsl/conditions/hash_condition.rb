# frozen_string_literal: true

require_relative "base_condition"

module Lutaml
  module UmlRepository
    module QueryDSL
      module Conditions
        # Hash-based condition for filtering query results
        #
        # Filters results based on attribute-value pairs specified in a hash.
        # All conditions must match for an object to be included in results.
        #
        # @example Filter by stereotype
        #   condition = HashCondition.new(stereotype: 'featureType')
        #   filtered = condition.apply(classes)
        #
        # @example Multiple conditions
        #   condition = HashCondition.new(
        #     stereotype: 'featureType',
        #     is_abstract: false
        #   )
        #   filtered = condition.apply(classes)
        class HashCondition < BaseCondition
          # Initialize with hash conditions
          #
          # @param conditions [Hash] Attribute-value pairs to match
          def initialize(conditions)
            super()
            @conditions = conditions
          end

          # Apply hash-based filtering to results
          #
          # @param results [Array] The collection to filter
          # @return [Array] Objects matching all conditions
          def apply(results)
            results.select do |obj|
              @conditions.all? do |key, value|
                matches_condition?(obj, key, value)
              end
            end
          end

          private

          # Check if object matches a single condition
          #
          # @param obj [Object] The object to check
          # @param key [Symbol, String] The attribute name
          # @param value [Object] The expected value
          # @return [Boolean] true if condition matches
          def matches_condition?(obj, key, value)
            return false unless obj.respond_to?(key)

            actual_value = obj.send(key)
            compare_values(actual_value, value)
          end

          # Compare actual and expected values
          #
          # @param actual [Object] The actual value from object
          # @param expected [Object] The expected value
          # @return [Boolean] true if values match
          def compare_values(actual, expected)
            case expected
            when Regexp
              expected.match?(actual.to_s)
            when Proc
              expected.call(actual)
            else
              # Handle array attributes (e.g., stereotype)
              if actual.is_a?(Array)
                actual.include?(expected)
              else
                actual == expected
              end
            end
          end
        end
      end
    end
  end
end
