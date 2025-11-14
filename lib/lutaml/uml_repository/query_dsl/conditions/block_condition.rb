# frozen_string_literal: true

require_relative "base_condition"

module Lutaml
  module UmlRepository
    module QueryDSL
      module Conditions
        # Block-based condition for custom filtering logic
        #
        # Allows arbitrary filtering logic to be specified using a Ruby block.
        # The block receives each object and should return true/false.
        #
        # @example Filter by attribute count
        #   condition = BlockCondition.new { |c| c.attributes.size > 10 }
        #   filtered = condition.apply(classes)
        #
        # @example Complex filtering
        #   condition = BlockCondition.new do |c|
        #     c.attributes.any? && c.associations.empty?
        #   end
        #   filtered = condition.apply(classes)
        class BlockCondition < BaseCondition
          # Initialize with a filtering block
          #
          # @param block [Proc] The block to use for filtering
          # @raise [ArgumentError] if no block provided
          def initialize(&block)
            super()
            raise ArgumentError, "Block required" unless block

            @block = block
          end

          # Apply block-based filtering to results
          #
          # @param results [Array] The collection to filter
          # @return [Array] Objects for which block returns true
          def apply(results)
            results.select(&@block)
          end
        end
      end
    end
  end
end
