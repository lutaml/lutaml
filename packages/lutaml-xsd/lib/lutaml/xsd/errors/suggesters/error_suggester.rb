# frozen_string_literal: true

module Lutaml
  module Xsd
    module Errors
      module Suggesters
        # Base class for error suggesters
        #
        # Suggesters generate contextual suggestions based on error information
        # to help users resolve issues.
        #
        # @example Implementing a custom suggester
        #   class MyCustomSuggester < ErrorSuggester
        #     def generate_suggestions(error)
        #       # Return array of Suggestion objects
        #       []
        #     end
        #   end
        #
        # @example Registering a suggester
        #   MyError.use_suggester(MyCustomSuggester)
        class ErrorSuggester
          # Generate suggestions for the given error
          #
          # @param error [EnhancedError] The error to generate suggestions for
          # @return [Array<Suggestion>] List of suggestions
          # @abstract Subclasses must implement this method
          def generate_suggestions(error)
            raise NotImplementedError,
                  "#{self.class} must implement #generate_suggestions"
          end

          protected

          # Check if suggestions are possible for this error
          #
          # @param error [EnhancedError] The error
          # @return [Boolean] True if suggestions can be generated
          def can_suggest?(error)
            error.context&.has_repository?
          end

          # Get repository from error context
          #
          # @param error [EnhancedError] The error
          # @return [SchemaRepository, nil] The repository
          def repository_from(error)
            error.context&.repository
          end

          # Get actual value from error context
          #
          # @param error [EnhancedError] The error
          # @return [String, nil] The actual value
          def actual_value_from(error)
            error.context&.actual_value
          end
        end
      end
    end
  end
end
