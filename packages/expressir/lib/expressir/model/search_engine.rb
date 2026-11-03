# frozen_string_literal: true

module Expressir
  module Model
    # SearchEngine for querying EXPRESS elements in a repository
    # Handles pattern matching, wildcards, regex, and element collection
    class SearchEngine
      # Element types that can be searched
      ELEMENT_TYPES = %w[
        schema entity type attribute derived_attribute inverse_attribute
        function procedure rule constant parameter variable
        where_rule unique_rule enumeration_item interface
      ].freeze

      # Type categories for filtering
      TYPE_CATEGORIES = %w[select enumeration aggregate defined].freeze

      attr_reader :repository

      # Initialize search engine with a repository
      # @param repository [Repository] Repository to search
      def initialize(repository)
        @repository = repository
        @repository.build_indexes if @repository.entity_index.nil?
      end

      # List all elements of a specific type
      # @param type [String] Element type to list
      # @param schema [String, nil] Filter by schema name
      # @param category [String, nil] Type category filter (for type elements)
      # @return [Array<Hash>] List of elements
      def list(type:, schema: nil, category: nil)
        elements = collect_elements(type: type, schema: schema,
                                    category: category)
        elements.map { |elem| element_to_hash(elem, type) }
      end

      # Search for elements matching a pattern
      # @param pattern [String] Search pattern
      # @param type [String, nil] Filter by element type
      # @param schema [String, nil] Limit to specific schema
      # @param category [String, nil] Type category filter
      # @param case_sensitive [Boolean] Enable case-sensitive matching
      # @param regex [Boolean] Treat pattern as regex
      # @param exact [Boolean] Exact match only
      # @return [Array<Hash>] Matching elements
      def search(pattern:, type: nil, schema: nil, category: nil,
                 case_sensitive: false, regex: false, exact: false)
        # Parse pattern
        pattern_parts = parse_pattern(pattern, case_sensitive: case_sensitive)

        # Determine types to search
        types_to_search = type ? [type] : ELEMENT_TYPES

        # Collect all matching elements
        results = []
        types_to_search.each do |elem_type|
          elements = collect_elements(type: elem_type, schema: schema,
                                      category: category)

          elements.each do |elem|
            if matches_pattern?(elem, pattern_parts, elem_type,
                                case_sensitive: case_sensitive,
                                regex: regex, exact: exact)
              results << element_to_hash(elem, elem_type)
            end
          end
        end

        results
      end

      # Count elements matching criteria
      # @param type [String] Element type
      # @param schema [String, nil] Filter by schema
      # @param category [String, nil] Type category filter
      # @return [Integer] Count of elements
      def count(type:, schema: nil, category: nil)
        collect_elements(type: type, schema: schema, category: category).size
      end

      # Search with depth filtering
      # @param pattern [String] Search pattern
      # @param max_depth [Integer] Maximum path depth (1=schema, 2=entity, 3=attribute)
      # @param options [Hash] Additional search options
      # @return [Array<Hash>] Filtered results
      def search_with_depth(pattern:, max_depth:, **)
        return [] if max_depth <= 0

        results = search(pattern: pattern, **)
        filter_by_depth(results, max_depth)
      end

      # Search with relevance ranking
      # @param pattern [String] Search pattern
      # @param boost_exact [Integer] Score boost for exact matches
      # @param boost_prefix [Integer] Score boost for prefix matches
      # @param options [Hash] Additional search options
      # @return [Array<Hash>] Ranked results with :relevance_score
      def search_ranked(pattern:, boost_exact: 10, boost_prefix: 5, **)
        results = search(pattern: pattern, **)
        rank_results(results, pattern, boost_exact, boost_prefix)
      end

      # Advanced search with multiple filters
      # @param pattern [String] Search pattern
      # @param max_depth [Integer, nil] Maximum path depth
      # @param ranked [Boolean] Enable relevance ranking
      # @param options [Hash] Additional filters and search options
      # @return [Array<Hash>] Filtered and optionally ranked results
      def search_advanced(pattern:, max_depth: nil, ranked: false, **)
        results = search(pattern: pattern, **)

        results = filter_by_depth(results, max_depth) if max_depth
        results = rank_results(results, pattern, 10, 5) if ranked

        results
      end

      private

      # Parse search pattern into components
      # @param pattern [String] Pattern to parse
      # @param case_sensitive [Boolean] Case sensitivity
      # @return [Hash] Parsed pattern with parts
      def parse_pattern(pattern, case_sensitive: false)
        normalized = case_sensitive ? pattern : pattern.downcase
        parts = normalized.split(".")

        {
          raw: pattern,
          normalized: normalized,
          parts: parts,
          schema_part: parts[0],
          element_parts: parts[1..] || [],
        }
      end

      # Check if element matches pattern
      # @param element [ModelElement] Element to check
      # @param pattern_parts [Hash] Parsed pattern
      # @param element_type [String] Type of element
      # @param case_sensitive [Boolean] Case sensitivity
      # @param regex [Boolean] Use regex matching
      # @param exact [Boolean] Exact match only
      # @return [Boolean] True if matches
      def matches_pattern?(element, pattern_parts, _element_type,
                          case_sensitive: false, regex: false, exact: false)
        # Duck typing - check if element responds to path/id
        element_path = begin
          element.path
        rescue StandardError
          element.id
        end
        return false unless element_path

        element_id = begin
          element.id
        rescue StandardError
          nil
        end

        search_path = case_sensitive ? element_path : element_path.downcase
        search_id = element_id && !case_sensitive ? element_id.downcase : element_id
        pattern = pattern_parts[:normalized]

        if regex
          match_regex(search_path,
                      pattern) || (search_id && match_regex(search_id, pattern))
        elsif exact
          search_path == pattern
        elsif pattern_parts[:parts].size == 1
          # For simple patterns (no dots or single part), also match against just the element ID
          match_wildcard(search_path, pattern_parts) ||
            (search_id && match_part(search_id, pattern))
        else
          match_wildcard(search_path, pattern_parts)
        end
      end

      # Match using regex
      # @param path [String] Element path
      # @param pattern [String] Regex pattern
      # @return [Boolean] True if matches
      def match_regex(path, pattern)
        Regexp.new(pattern).match?(path)
      rescue RegexpError
        false
      end

      # Match using wildcard pattern
      # @param path [String] Element path
      # @param pattern_parts [Hash] Parsed pattern
      # @return [Boolean] True if matches
      def match_wildcard(path, pattern_parts)
        path_parts = path.split(".")
        pattern_array = pattern_parts[:parts]

        # Handle different wildcard scenarios
        match_wildcard_parts(path_parts, pattern_array)
      end

      # Match path parts against pattern parts with wildcards
      # @param path_parts [Array<String>] Path components
      # @param pattern_parts [Array<String>] Pattern components
      # @return [Boolean] True if matches
      def match_wildcard_parts(path_parts, pattern_parts)
        # If pattern has no wildcards and different length, no match
        unless pattern_parts.include?("*")
          return false if path_parts.size != pattern_parts.size

          return path_parts.zip(pattern_parts).all? do |path_part, pattern_part|
            match_part(path_part, pattern_part)
          end
        end

        # Handle wildcards
        match_with_wildcards(path_parts, pattern_parts)
      end

      # Match individual part with potential prefix/suffix wildcards
      # @param part [String] Path part
      # @param pattern [String] Pattern part
      # @return [Boolean] True if matches
      def match_part(part, pattern)
        return true if pattern == "*"

        if pattern.include?("*")
          # Convert wildcard to regex
          regex_pattern = "^#{Regexp.escape(pattern).gsub('\\*', '.*')}$"
          Regexp.new(regex_pattern).match?(part)
        else
          # Support substring matching for simple patterns
          part.include?(pattern)
        end
      end

      # Match path with wildcard patterns
      # @param path_parts [Array<String>] Path components
      # @param pattern_parts [Array<String>] Pattern components with wildcards
      # @return [Boolean] True if matches
      def match_with_wildcards(path_parts, pattern_parts)
        # Simple implementation: match each level
        # If pattern is shorter but has *, try to match flexibly

        pi = 0 # pattern index
        li = 0 # path index

        while pi < pattern_parts.size && li < path_parts.size
          if pattern_parts[pi] == "*"
            # Wildcard matches one element
            pi += 1
            li += 1
          elsif match_part(path_parts[li], pattern_parts[pi])
            pi += 1
            li += 1
          else
            return false
          end
        end

        # Check if we consumed both arrays
        pi == pattern_parts.size && li == path_parts.size
      end

      # Collect elements of a specific type
      # @param type [String] Element type
      # @param schema [String, nil] Schema filter
      # @param category [String, nil] Category filter
      # @return [Array<ModelElement>] Collected elements
      def collect_elements(type:, schema: nil, category: nil)
        # Guard against nil schemas collection
        return [] unless @repository.schemas

        schemas_to_search = if schema
                              [@repository.schemas.find do |s|
                                s.id == schema
                              end].compact
                            else
                              @repository.schemas
                            end

        case type
        when "schema"
          schemas_to_search
        when "entity"
          collect_from_schemas(schemas_to_search, :entities)
        when "type"
          types = collect_from_schemas(schemas_to_search, :types)
          category ? filter_types_by_category(types, category) : types
        when "attribute"
          collect_attributes(schemas_to_search)
        when "derived_attribute"
          collect_derived_attributes(schemas_to_search)
        when "inverse_attribute"
          collect_inverse_attributes(schemas_to_search)
        when "function"
          collect_from_schemas(schemas_to_search, :functions)
        when "procedure"
          collect_from_schemas(schemas_to_search, :procedures)
        when "rule"
          collect_from_schemas(schemas_to_search, :rules)
        when "constant"
          collect_from_schemas(schemas_to_search, :constants)
        when "parameter"
          collect_parameters(schemas_to_search)
        when "variable"
          collect_variables(schemas_to_search)
        when "where_rule"
          collect_where_rules(schemas_to_search)
        when "unique_rule"
          collect_unique_rules(schemas_to_search)
        when "enumeration_item"
          collect_enumeration_items(schemas_to_search)
        when "interface"
          collect_from_schemas(schemas_to_search, :interfaces)
        else
          []
        end
      end

      # Collect elements from schemas using a method
      # @param schemas [Array<Schema>] Schemas to search
      # @param method [Symbol] Method to call on schema
      # @return [Array] Collected elements
      def collect_from_schemas(schemas, method)
        # Guard against nil schemas array
        return [] unless schemas

        schemas.flat_map { |s| s.public_send(method) || [] }
      end

      # Collect all attributes from entities
      # @param schemas [Array<Schema>] Schemas to search
      # @return [Array<Attribute>] All attributes
      def collect_attributes(schemas)
        # Guard against nil schemas
        return [] unless schemas

        entities = collect_from_schemas(schemas, :entities)
        entities.flat_map { |e| e.attributes || [] }.select do |attr|
          !attr.is_a?(Declarations::DerivedAttribute) &&
            !attr.is_a?(Declarations::InverseAttribute)
        end
      end

      # Collect derived attributes from entities
      # @param schemas [Array<Schema>] Schemas to search
      # @return [Array<DerivedAttribute>] Derived attributes
      def collect_derived_attributes(schemas)
        # Guard against nil schemas
        return [] unless schemas

        entities = collect_from_schemas(schemas, :entities)
        entities.flat_map { |e| e.attributes || [] }.grep(Declarations::DerivedAttribute)
      end

      # Collect inverse attributes from entities
      # @param schemas [Array<Schema>] Schemas to search
      # @return [Array<InverseAttribute>] Inverse attributes
      def collect_inverse_attributes(schemas)
        # Guard against nil schemas
        return [] unless schemas

        entities = collect_from_schemas(schemas, :entities)
        entities.flat_map { |e| e.attributes || [] }.grep(Declarations::InverseAttribute)
      end

      # Collect parameters from functions and procedures
      # @param schemas [Array<Schema>] Schemas to search
      # @return [Array<Parameter>] All parameters
      def collect_parameters(schemas)
        # Guard against nil schemas
        return [] unless schemas

        functions = collect_from_schemas(schemas, :functions)
        procedures = collect_from_schemas(schemas, :procedures)
        (functions + procedures).flat_map { |f| f.parameters || [] }
      end

      # Collect variables from functions and procedures
      # @param schemas [Array<Schema>] Schemas to search
      # @return [Array<Variable>] All variables
      def collect_variables(schemas)
        # Guard against nil schemas
        return [] unless schemas

        functions = collect_from_schemas(schemas, :functions)
        procedures = collect_from_schemas(schemas, :procedures)
        (functions + procedures).flat_map { |f| f.variables || [] }
      end

      # Collect where rules from entities and types
      # @param schemas [Array<Schema>] Schemas to search
      # @return [Array<WhereRule>] All where rules
      def collect_where_rules(schemas)
        # Guard against nil schemas
        return [] unless schemas

        entities = collect_from_schemas(schemas, :entities)
        types = collect_from_schemas(schemas, :types)
        (entities + types).flat_map { |e| e.where_rules || [] }
      end

      # Collect unique rules from entities
      # @param schemas [Array<Schema>] Schemas to search
      # @return [Array<UniqueRule>] All unique rules
      def collect_unique_rules(schemas)
        # Guard against nil schemas
        return [] unless schemas

        entities = collect_from_schemas(schemas, :entities)
        entities.flat_map { |e| e.unique_rules || [] }
      end

      # Collect enumeration items from enumeration types
      # @param schemas [Array<Schema>] Schemas to search
      # @return [Array<EnumerationItem>] All enumeration items
      def collect_enumeration_items(schemas)
        # Guard against nil schemas
        return [] unless schemas

        types = collect_from_schemas(schemas, :types)
        types.flat_map { |t| t.enumeration_items || [] }
      end

      # Filter types by category
      # @param types [Array<Type>] Types to filter
      # @param category [String] Category to filter by
      # @return [Array<Type>] Filtered types
      def filter_types_by_category(types, category)
        types.select do |type|
          @repository.type_index.categorize(type) == category
        end
      end

      # Convert element to hash representation
      # @param element [ModelElement] Element to convert
      # @param type [String] Element type
      # @return [Hash] Element data
      def element_to_hash(element, type)
        # Duck typing - try to get id/path from element
        element_id = begin
          element.id
        rescue StandardError
          nil
        end

        element_path = begin
          element.path
        rescue StandardError
          nil
        end

        hash = {
          id: element_id,
          type: type,
          path: element_path,
        }

        # Add schema for non-schema elements
        if type != "schema"
          begin
            if element.parent
              schema = find_parent_schema(element)
              hash[:schema] = schema.id if schema
            end
          rescue StandardError
            # Element doesn't have parent or parent chain
          end
        end

        # Add category for types
        if type == "type"
          hash[:category] = @repository.type_index.categorize(element)
        end

        hash
      end

      # Find parent schema of an element
      # @param element [ModelElement] Element to find schema for
      # @return [Schema, nil] Parent schema
      def find_parent_schema(element)
        current = element
        while current
          return current if current.is_a?(Declarations::Schema)

          current = current.parent
        end
      rescue StandardError
        # Handle objects that don't fully implement the interface
        nil
      end

      # Filter results by maximum path depth
      # @param results [Array<Hash>] Search results
      # @param max_depth [Integer] Maximum depth
      # @return [Array<Hash>] Filtered results
      def filter_by_depth(results, max_depth)
        results.select do |result|
          next true unless result[:path]

          result[:path].split(".").size <= max_depth
        end
      end

      # Rank results by relevance
      # @param results [Array<Hash>] Search results
      # @param pattern [String] Search pattern
      # @param boost_exact [Integer] Exact match boost
      # @param boost_prefix [Integer] Prefix match boost
      # @return [Array<Hash>] Sorted results with scores
      def rank_results(results, pattern, boost_exact, boost_prefix)
        normalized_pattern = pattern.downcase

        results.map do |result|
          score = calculate_relevance_score(result, normalized_pattern,
                                            boost_exact, boost_prefix)
          result.merge(relevance_score: score)
        end.sort_by { |r| -r[:relevance_score] }
      end

      # Calculate relevance score for a result
      # @param result [Hash] Search result
      # @param pattern [String] Normalized search pattern
      # @param boost_exact [Integer] Exact match boost
      # @param boost_prefix [Integer] Prefix match boost
      # @return [Integer] Relevance score
      def calculate_relevance_score(result, pattern, boost_exact, boost_prefix)
        score = 0
        id = (result[:id] || "").downcase

        # Exact match gets highest score
        score += boost_exact if id == pattern

        # Prefix match gets medium score
        score += boost_prefix if id.start_with?(pattern)

        # Shorter paths rank higher (max 10 points)
        path_depth = result[:path]&.split(".")&.size || 1
        score += [10 - path_depth, 0].max

        # Schema-level results rank higher
        score += 5 if result[:type] == "schema"

        score
      end
    end
  end
end
