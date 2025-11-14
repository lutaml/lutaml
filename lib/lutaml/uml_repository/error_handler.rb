# frozen_string_literal: true

module Lutaml
  module UmlRepository
    # Error handler for user-friendly error messages with suggestions.
    #
    # Provides helpful error messages when classes, packages, or other model
    # elements are not found. Uses fuzzy matching (Levenshtein distance) to
    # suggest similar names that might be what the user intended.
    #
    # @example Class not found
    #   handler = ErrorHandler.new(repository)
    #   handler.class_not_found_error("ModelRoot::Buildng")
    #   # => Raises error with suggestion: Did you mean "ModelRoot::Building"?
    #
    # @example Package not found
    #   handler.package_not_found_error("ModelRoot::i-UR::urf")
    #   # => Raises error with suggestions for similar packages
    class ErrorHandler
      # Maximum Levenshtein distance for suggestions
      MAX_SUGGESTION_DISTANCE = 3

      # Maximum number of suggestions to show
      MAX_SUGGESTIONS = 5

      # @return [UmlRepository] The repository to search for suggestions
      attr_reader :repository

      # Initialize a new ErrorHandler.
      #
      # @param repository [UmlRepository] Repository to use for suggestions
      def initialize(repository)
        @repository = repository
      end

      # Raise a class not found error with suggestions.
      #
      # Searches for similar class names using fuzzy matching and provides
      # helpful suggestions in the error message.
      #
      # @param attempted_qname [String] The qualified name that was attempted
      # @raise [NameError] With helpful message and suggestions
      # @example
      #   handler.class_not_found_error("ModelRoot::Buildng")
      def class_not_found_error(attempted_qname)
        suggestions = suggest_similar_classes(attempted_qname)

        message = "Class not found: #{attempted_qname}"

        if suggestions.any?
          message += "\n\nDid you mean one of these?"
          suggestions.each { |s| message += "\n  - #{s}" }
        else
          message += "\n\nTip: Use the 'search' or 'find' commands to explore " \
                     "available classes."
        end

        raise NameError, message
      end

      # Raise a package not found error with suggestions.
      #
      # Searches for similar package paths using fuzzy matching and provides
      # helpful suggestions in the error message.
      #
      # @param attempted_path [String] The package path that was attempted
      # @raise [NameError] With helpful message and suggestions
      # @example
      #   handler.package_not_found_error("ModelRoot::i-UR::urf")
      def package_not_found_error(attempted_path)
        suggestions = suggest_similar_packages(attempted_path)

        message = "Package not found: #{attempted_path}"

        if suggestions.any?
          message += "\n\nDid you mean one of these?"
          suggestions.each { |s| message += "\n  - #{s}" }
        else
          message += "\n\nTip: Use the 'list' or 'tree' commands to explore " \
                     "available packages."
        end

        raise NameError, message
      end

      # Suggest similar class names based on Levenshtein distance.
      #
      # @param attempted [String] The attempted qualified name
      # @return [Array<String>] Array of suggested qualified names, sorted by
      #   similarity
      # @example
      #   suggestions = handler.suggest_similar_classes("ModelRoot::Buildng")
      #   # => ["ModelRoot::Building", "ModelRoot::BuildingPart"]
      def suggest_similar_classes(attempted)
        return [] unless repository.indexes[:classes_by_qname]

        all_qnames = repository.indexes[:classes_by_qname].keys
        find_similar_names(attempted, all_qnames)
      end

      # Suggest similar package paths based on Levenshtein distance.
      #
      # @param attempted [String] The attempted package path
      # @return [Array<String>] Array of suggested package paths, sorted by
      #   similarity
      # @example
      #   suggestions = handler.suggest_similar_packages("ModelRoot::i-UR")
      #   # => ["ModelRoot::i-UR::urf", "ModelRoot::i-UR::core"]
      def suggest_similar_packages(attempted)
        return [] unless repository.indexes[:packages_by_path]

        all_paths = repository.indexes[:packages_by_path].keys
        find_similar_names(attempted, all_paths)
      end

      # Calculate Levenshtein distance between two strings.
      #
      # The Levenshtein distance is the minimum number of single-character edits
      # (insertions, deletions, or substitutions) required to change one string
      # into another.
      #
      # @param str1 [String] First string
      # @param str2 [String] Second string
      # @return [Integer] The Levenshtein distance
      # @example
      #   distance = handler.levenshtein_distance("kitten", "sitting")
      #   # => 3
      def levenshtein_distance(str1, str2)
        return str2.length if str1.empty?
        return str1.length if str2.empty?

        # Create a matrix to store distances
        matrix = Array.new(str1.length + 1) do |i|
          Array.new(str2.length + 1) do |j|
            if i.zero?
              j
            else
              (j.zero? ? i : 0)
            end
          end
        end

        # Calculate distances
        (1..str1.length).each do |i|
          (1..str2.length).each do |j|
            cost = str1[i - 1] == str2[j - 1] ? 0 : 1
            matrix[i][j] = [
              matrix[i - 1][j] + 1,      # deletion
              matrix[i][j - 1] + 1,      # insertion
              matrix[i - 1][j - 1] + cost, # substitution
            ].min
          end
        end

        matrix[str1.length][str2.length]
      end

      private

      # Find similar names from a list using Levenshtein distance.
      #
      # @param attempted [String] The attempted name
      # @param candidates [Array<String>] List of candidate names
      # @return [Array<String>] Sorted array of similar names
      def find_similar_names(attempted, candidates)
        # Calculate distances for all candidates
        distances = candidates.map do |candidate|
          distance = levenshtein_distance(
            attempted.downcase,
            candidate.downcase,
          )
          { name: candidate, distance: distance }
        end

        # Filter by maximum distance and sort
        similar = distances
          .select { |d| d[:distance] <= MAX_SUGGESTION_DISTANCE }
          .sort_by { |d| d[:distance] }
          .take(MAX_SUGGESTIONS)
          .map { |d| d[:name] }

        # If no close matches, try substring matching
        if similar.empty?
          similar = find_substring_matches(attempted, candidates)
        end

        similar
      end

      # Find names containing the attempted string as a substring.
      #
      # @param attempted [String] The attempted name
      # @param candidates [Array<String>] List of candidate names
      # @return [Array<String>] Array of matching names
      def find_substring_matches(attempted, candidates)
        attempted_lower = attempted.downcase
        candidates
          .select { |c| c.downcase.include?(attempted_lower) }
          .take(MAX_SUGGESTIONS)
      end
    end
  end
end
