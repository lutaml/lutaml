# frozen_string_literal: true

require_relative "../suggestion"

module Lutaml
  module Xsd
    module Errors
      module Suggesters
        # Fuzzy string matching utility for finding similar items
        #
        # @example Finding similar types
        #   matcher = FuzzyMatcher.new(repository)
        #   similar = matcher.find_similar_types("CdeType", limit: 5)
        class FuzzyMatcher
          # @return [SchemaRepository] The schema repository to search
          attr_reader :repository

          # @return [Float] Minimum similarity threshold (0.0 to 1.0)
          attr_reader :min_similarity

          # Initialize fuzzy matcher
          #
          # @param repository [SchemaRepository] The schema repository
          # @param min_similarity [Float] Minimum similarity threshold (default: 0.6)
          def initialize(repository, min_similarity: 0.6)
            @repository = repository
            @min_similarity = min_similarity
          end

          # Find types similar to the query string
          #
          # @param query [String] The query string
          # @param limit [Integer] Maximum number of results (default: 5)
          # @return [Array<Suggestion>] Similar types as suggestions
          def find_similar_types(query, limit: 5)
            return [] unless repository

            candidates = collect_type_candidates
            scored = score_candidates(candidates, query)
            filtered = scored.select { |_, score| score >= min_similarity }
            sorted = filtered.sort_by { |_, score| -score }

            sorted.take(limit).map do |name, score|
              Suggestion.new(
                text: name,
                similarity: score,
                explanation: "Did you mean '#{name}'?",
              )
            end
          end

          # Calculate Levenshtein distance between two strings
          #
          # @param str1 [String] First string
          # @param str2 [String] Second string
          # @return [Integer] Edit distance
          def levenshtein_distance(str1, str2)
            return str2.length if str1.empty?
            return str1.length if str2.empty?

            matrix = Array.new(str1.length + 1) { Array.new(str2.length + 1) }

            (0..str1.length).each { |i| matrix[i][0] = i }
            (0..str2.length).each { |j| matrix[0][j] = j }

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

          # Calculate similarity score (0.0 to 1.0) based on Levenshtein distance
          #
          # @param str1 [String] First string
          # @param str2 [String] Second string
          # @return [Float] Similarity score
          def similarity_score(str1, str2)
            return 1.0 if str1 == str2
            return 0.0 if str1.empty? || str2.empty?

            distance = levenshtein_distance(str1.downcase, str2.downcase)
            max_length = [str1.length, str2.length].max
            1.0 - (distance.to_f / max_length)
          end

          private

          # Collect type name candidates from repository
          #
          # @return [Array<String>] Type names
          def collect_type_candidates
            candidates = []

            # Collect simple types
            repository.simple_types&.each do |type|
              candidates << type.name
            end

            # Collect complex types
            repository.complex_types&.each do |type|
              candidates << type.name
            end

            # Fallback: try to get all types
            if candidates.empty? && repository.types
              repository.types.each do |type|
                candidates << type.name
              end
            end

            candidates.compact.uniq
          end

          # Score candidates against query
          #
          # @param candidates [Array<String>] Candidate strings
          # @param query [String] Query string
          # @return [Hash<String, Float>] Candidates with scores
          def score_candidates(candidates, query)
            candidates.each_with_object({}) do |candidate, scores|
              scores[candidate] = similarity_score(query, candidate)
            end
          end
        end
      end
    end
  end
end
