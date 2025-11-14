# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module QueryDSL
      module Conditions
        # Base class for query conditions
        #
        # Provides the interface for filtering results in query operations.
        # All concrete condition classes must implement the {#apply} method.
        #
        # @abstract Subclass and override {#apply} to implement a custom
        #   condition
        class BaseCondition
          # Apply the condition to filter results
          #
          # @param results [Array] The collection to filter
          # @return [Array] The filtered collection
          # @raise [NotImplementedError] if not implemented by subclass
          def apply(results)
            raise NotImplementedError,
                  "#{self.class} must implement #apply"
          end
        end
      end
    end
  end
end
