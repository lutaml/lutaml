# frozen_string_literal: true

require_relative "error_suggester"
require_relative "fuzzy_matcher"

module Lutaml
  module Xsd
    module Errors
      module Suggesters
        # Suggester for type not found errors
        #
        # Suggests similar type names using fuzzy matching
        #
        # @example Using the suggester
        #   class TypeNotFoundError < EnhancedError
        #     use_suggester TypeNotFoundSuggester
        #   end
        #
        #   error = TypeNotFoundError.new(
        #     "Type 'CdeType' not found",
        #     context: {
        #       actual_value: "CdeType",
        #       repository: schema_repository
        #     }
        #   )
        #   error.suggestions # => [Suggestion(text: "CodeType", similarity: 0.88), ...]
        class TypeNotFoundSuggester < ErrorSuggester
          # @return [Integer] Maximum number of suggestions
          DEFAULT_LIMIT = 5

          # @return [Float] Minimum similarity threshold
          DEFAULT_MIN_SIMILARITY = 0.6

          # Generate suggestions for type not found errors
          #
          # @param error [EnhancedError] The error
          # @return [Array<Suggestion>] List of suggestions
          def generate_suggestions(error)
            return [] unless can_suggest?(error)

            query = actual_value_from(error)
            return [] unless query

            repository = repository_from(error)
            return [] unless repository

            matcher = FuzzyMatcher.new(repository,
                                       min_similarity: min_similarity)
            matcher.find_similar_types(query, limit: suggestion_limit)
          end

          private

          # Get suggestion limit from configuration or default
          #
          # @return [Integer] Suggestion limit
          def suggestion_limit
            DEFAULT_LIMIT
          end

          # Get minimum similarity threshold from configuration or default
          #
          # @return [Float] Minimum similarity
          def min_similarity
            DEFAULT_MIN_SIMILARITY
          end
        end
      end
    end
  end
end
