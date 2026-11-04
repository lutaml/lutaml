# frozen_string_literal: true

module Lutaml
  module Xsd
    # Search engine for finding types in a schema repository
    # Supports searching by name, documentation, or both with relevance ranking
    class TypeSearcher
      # Search result with relevance score
      class SearchResult
        attr_reader :qualified_name, :local_name, :namespace, :category,
                    :schema_file, :documentation, :relevance_score,
                    :match_type, :definition

        def initialize(qualified_name:, local_name:, namespace:, category:,
                       schema_file:, documentation:, relevance_score:,
                       match_type:, definition:)
          @qualified_name = qualified_name
          @local_name = local_name
          @namespace = namespace
          @category = category
          @schema_file = schema_file
          @documentation = documentation
          @relevance_score = relevance_score
          @match_type = match_type
          @definition = definition
        end

        # Convert to hash for JSON/YAML output
        # @return [Hash]
        def to_h
          {
            qualified_name: qualified_name,
            local_name: local_name,
            namespace: namespace,
            category: category,
            schema_file: schema_file,
            documentation: documentation,
            relevance_score: relevance_score,
            match_type: match_type,
          }
        end
      end

      # Initialize searcher with a repository
      # @param repository [SchemaRepository] The schema repository to search
      def initialize(repository)
        @repository = repository
        @type_index = repository.instance_variable_get(:@type_index)
      end

      # Search for types matching the query
      # @param query [String] The search query
      # @param in_field [String] Where to search: "name", "documentation", or "both"
      # @param namespace [String, nil] Filter by namespace URI
      # @param category [String, Symbol, nil] Filter by category
      # @param limit [Integer] Maximum number of results to return
      # @return [Array<SearchResult>] Sorted search results
      def search(query, in_field: "both", namespace: nil, category: nil,
limit: 20)
        return [] if query.nil? || query.strip.empty?

        query = query.strip.downcase
        results = []

        # Get all types from the index
        all_types = @type_index.all

        all_types.each_value do |type_info|
          # Apply namespace filter
          next if namespace && type_info[:namespace] != namespace

          # Apply category filter
          if category
            category_sym = category.to_sym
            next if type_info[:type] != category_sym
          end

          # Extract type information
          definition = type_info[:definition]
          next unless definition&.name

          local_name = definition.name
          type_namespace = type_info[:namespace]
          type_category = type_info[:type]
          schema_file = type_info[:schema_file]

          # Build qualified name
          prefix = @repository.namespace_to_prefix(type_namespace)
          qualified_name = prefix ? "#{prefix}:#{local_name}" : local_name

          # Extract documentation
          documentation = extract_documentation(definition)

          # Calculate relevance score based on search field
          score_result = calculate_relevance(
            query: query,
            local_name: local_name,
            documentation: documentation,
            in_field: in_field,
          )

          # Skip if no match
          next if score_result[:score].zero?

          # Create search result
          results << SearchResult.new(
            qualified_name: qualified_name,
            local_name: local_name,
            namespace: type_namespace,
            category: type_category,
            schema_file: schema_file,
            documentation: documentation,
            relevance_score: score_result[:score],
            match_type: score_result[:match_type],
            definition: definition,
          )
        end

        # Sort by relevance score (highest first), then by name
        results.sort! do |a, b|
          if a.relevance_score == b.relevance_score
            a.qualified_name <=> b.qualified_name
          else
            b.relevance_score <=> a.relevance_score
          end
        end

        # Apply limit
        results.take(limit)
      end

      private

      # Calculate relevance score for a type
      # @param query [String] The search query (lowercase)
      # @param local_name [String] The type's local name
      # @param documentation [String] The type's documentation
      # @param in_field [String] Where to search
      # @return [Hash] Score and match type
      def calculate_relevance(query:, local_name:, documentation:, in_field:)
        name_lower = local_name.downcase
        doc_lower = documentation.downcase

        # Relevance scores
        # Exact name match: 1000
        # Starts with (name): 500
        # Contains (name): 250
        # Exact word in documentation: 100
        # Contains in documentation: 50

        case in_field
        when "name"
          calculate_name_score(query, name_lower)
        when "documentation"
          calculate_documentation_score(query, doc_lower)
        when "both"
          name_result = calculate_name_score(query, name_lower)
          doc_result = calculate_documentation_score(query, doc_lower)

          # Return the best match
          if name_result[:score] >= doc_result[:score]
            name_result
          else
            doc_result
          end
        else
          { score: 0, match_type: "none" }
        end
      end

      # Calculate relevance score for name matching
      # @param query [String] The search query (lowercase)
      # @param name_lower [String] The name to match against (lowercase)
      # @return [Hash] Score and match type
      def calculate_name_score(query, name_lower)
        if name_lower == query
          { score: 1000, match_type: "exact_name" }
        elsif name_lower.start_with?(query)
          { score: 500, match_type: "name_starts_with" }
        elsif name_lower.include?(query)
          { score: 250, match_type: "name_contains" }
        else
          { score: 0, match_type: "none" }
        end
      end

      # Calculate relevance score for documentation matching
      # @param query [String] The search query (lowercase)
      # @param doc_lower [String] The documentation to match against (lowercase)
      # @return [Hash] Score and match type
      def calculate_documentation_score(query, doc_lower)
        return { score: 0, match_type: "none" } if doc_lower.empty?

        # Check for exact word match (with word boundaries)
        if /\b#{Regexp.escape(query)}\b/.match?(doc_lower)
          { score: 100, match_type: "doc_exact_word" }
        elsif doc_lower.include?(query)
          { score: 50, match_type: "doc_contains" }
        else
          { score: 0, match_type: "none" }
        end
      end

      # Extract documentation from a type definition
      # @param definition [Object] The type definition
      # @return [String] The documentation text or empty string
      def extract_documentation(definition)
        return "" unless definition.annotation&.documentation

        docs = definition.annotation.documentation
        docs = [docs] unless docs.is_a?(Array)

        docs.filter_map do |doc|
          content = doc.content || doc.to_s
          content&.strip
        end.first || ""
      end
    end
  end
end
