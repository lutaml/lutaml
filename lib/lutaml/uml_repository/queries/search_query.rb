# frozen_string_literal: true

require_relative "base_query"
require_relative "../search_result"

module Lutaml
  module UmlRepository
    module Queries
      # Query service for search operations.
      #
      # Provides methods for fuzzy text search and regex pattern matching
      # across classes, attributes, and associations in the UML model.
      #
      # @example Searching for text
      #   query = SearchQuery.new(document, indexes)
      #   results = query.search("Building")
      #   # => { classes: [...], attributes: [...], associations: [...],
      #   total: 15 }
      #
      # @example Pattern matching
      #   results = query.search("^Urban", type: :class)
      class SearchQuery < BaseQuery
        # Perform a fuzzy text search across the model.
        #
        # Searches for the query string in class names, attribute names, and
        # association names. Can optionally search in documentation fields.
        # The search is case-insensitive.
        #
        # @param query_string [String] The text to search for
        # @param types [Array<Symbol>] Types to search in - :class, :attribute,
        #   :association (default: [:class, :attribute, :association])
        # @param fields [Array<Symbol>] Fields to search in
        # - :name, :documentation
        #   (default: [:name])
        # @return [Hash] Search results with keys :classes, :attributes,
        #   :associations, :total
        # @example
        #   results = query.search("building")
        #   results = query.search("urban", fields: [:name, :documentation])
        def search( # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          query_string, types: %i[class attribute association],
                        fields: [:name], case_sensitive: false
        )
          return empty_result if query_string.nil? || query_string.empty?

          results = {
            classes: [],
            attributes: [],
            associations: [],
            total: 0,
          }

          # Search classes
          if types.include?(:class)
            results[:classes] = search_classes(
              query_string, fields: fields, case_sensitive: case_sensitive
            )
          end

          # Search attributes
          if types.include?(:attribute)
            results[:attributes] = search_attributes(
              query_string, fields: fields, case_sensitive: case_sensitive
            )
          end

          # Search associations
          if types.include?(:association)
            results[:associations] = search_associations(
              query_string, fields: fields, case_sensitive: case_sensitive
            )
          end

          results[:total] = results[:classes].size +
            results[:attributes].size +
            results[:associations].size

          results
        end

        # Perform a full-text search across all text fields.
        # Searches for the query string in all relevant text fields of classes
        # and packages.
        #
        # @param query_string [String] The text to search for
        # @param fields [Array<Symbol>] Fields to search in - :name, :
        def full_text_search( # rubocop:disable Metrics/MethodLength
          query_string,
          fields: [:name], case_sensitive: false
        )
          results = empty_full_text_search_result
          if query_string.nil? || query_string.empty?
            return results
          end

          # Search classes
          results[:classes] = search_classes(
            query_string, fields: fields, case_sensitive: case_sensitive
          )

          # Search packages
          results[:packages] = search_packages(
            query_string, case_sensitive: case_sensitive
          )

          results[:total] = results[:classes].size + results[:packages].size

          results
        end

        # Search for classes matching the query
        #
        # @param query [String] Query string
        # @param fields [Array<Symbol>] Fields to search in
        # @return [Array<SearchResult>] Matching search result objects
        def search_classes( # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          query, fields: [:name, :documentation],
          case_sensitive: false
        )
          pattern = regex_pattern_from_query(
            query, case_sensitive: case_sensitive
          )

          indexes[:qualified_names].map do |qname, entity|
            match_field = nil
            qualified_name = nil

            next unless entity.is_a?(Lutaml::Uml::Class)

            # Check fields for match
            fields.each do |field|
              if entity.respond_to?(field) &&
                  entity.send(field)&.match?(pattern)

                match_field = field
                qualified_name = qname
              end
            end

            if match_field
              SearchResult.new(
                element: entity,
                element_type: :class,
                qualified_name: qualified_name,
                package_path: extract_package_path(qualified_name),
                match_field: match_field,
              )
            end
          end.compact.uniq
        end

        def search_by_stereotype(query, case_sensitive: false) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          pattern = regex_pattern_from_query(
            query, case_sensitive: case_sensitive
          )

          matched_entities = indexes[:stereotypes]
            .map do |_stereotype, entities|
              entities.select do |entity|
                entity.respond_to?(:stereotype) &&
                  entity.stereotype&.match?(pattern)
              end.uniq
          end.compact.uniq.flatten

          matched_entities.map do |entity|
            SearchResult.new(
              element: entity,
              element_type: entity.class.name.split("::").last.downcase,
              qualified_name: "",
              package_path: "",
              match_field: :stereotype,
            )
          end
        end

        # Search for packages matching the query
        #
        # @param query [String] Query string
        # @param case_sensitive [Boolean] Whether the search is case-sensitive
        # @return [Array<Lutaml::Uml::Package>] Matching package objects
        def search_packages(query, case_sensitive: false) # rubocop:disable Metrics/MethodLength
          pattern = regex_pattern_from_query(
            query, case_sensitive: case_sensitive
          )

          indexes[:package_paths].map do |path_string, package|
            if path_string.to_s.match?(pattern)
              SearchResult.new(
                element: package,
                element_type: :package,
                qualified_name: path_string,
                package_path: path_string,
                match_field: :package_path,
              )
            end
          end.compact
        end

        def regex_pattern_from_query(query, case_sensitive: false)
          # handle wildcard '*' and glob patterns
          query = query.gsub("*", ".*") unless query.include?(".*")

          if case_sensitive
            Regexp.new(query)
          else
            Regexp.new(query, Regexp::IGNORECASE)
          end
        end

        # Search for attributes matching the query
        #
        # @param query [String] Query string
        # @param fields [Array<Symbol>] Fields to search in
        # @return [Array<Lutaml::Uml::Class>] Matching search result objects
        def search_attributes(query, fields: [:name], case_sensitive: false) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          pattern = regex_pattern_from_query(
            query, case_sensitive: case_sensitive
          )

          indexes[:qualified_names].map do |class_qname, entity| # rubocop:disable Metrics/BlockLength
            next unless entity.respond_to?(:attributes) && entity.attributes

            match_field = nil
            match_attr = nil
            qualified_name = nil

            entity.attributes.each do |attr|
              # Check attribute for match
              fields.each do |field|
                if attr.respond_to?(field) &&
                    attr.send(field)&.match?(pattern)

                  match_attr = attr
                  match_field = field
                  qualified_name = class_qname
                end
              end
            end

            if match_field
              SearchResult.new(
                element: match_attr,
                element_type: :attribute,
                qualified_name: "#{qualified_name}::#{match_attr.name}",
                package_path: extract_package_path(qualified_name),
                match_field: match_field,
                match_context: {
                  "class_name" => entity&.name,
                  "class_qname" => qualified_name,
                },
              )
            end
          end.compact.uniq
        end

        # Get all associations in the model
        #
        # @return [Array<Lutaml::Uml::Association>] All association objects
        def get_all_associations # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          all_associations = []

          # Get all associations defined at document level and
          if document.respond_to?(:associations) && document.associations
            all_associations << document.associations
          end

          # Get all associations defined within classes
          indexes[:qualified_names].each_value do |entity|
            next unless entity.respond_to?(:associations) && entity.associations

            all_associations << entity.associations
          end

          all_associations.flatten.uniq
        end

        # Search for associations matching the query
        #
        # @param query [String] Query string
        # @param fields [Array<Symbol>] Fields to search in
        # @return [Array<SearchResult>] Matching search result objects
        def search_associations(query, # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          fields: %i[
            name owner_end member_end owner_end_attribute_name
            member_end_attribute_name documentation
          ],
          case_sensitive: false)
          all_associations = get_all_associations
          pattern = regex_pattern_from_query(
            query, case_sensitive: case_sensitive
          )

          all_associations.map do |assoc|
            match_field = nil

            fields.each do |field|
              if assoc.respond_to?(field) && assoc.send(field)&.match?(pattern)
                match_field = field
              end
            end

            if match_field
              SearchResult.new(
                element: assoc,
                element_type: :association,
                qualified_name: assoc.name || "(unnamed)",
                package_path: "",
                match_field: match_field,
                match_context: {
                  "source" => assoc.owner_end,
                  "target" => assoc.member_end,
                },
              )
            end
          end.compact.uniq
        end

        private

        # Extract package path from qualified name
        #
        # @param qualified_name [String] Qualified name
        # (e.g., "pkg1::pkg2::Class")
        # @return [String] Package path (e.g., "pkg1::pkg2")
        def extract_package_path(qualified_name)
          parts = qualified_name.to_s.split("::")
          return "" if parts.size <= 1

          parts[0..-2].join("::")
        end

        # Return empty search result
        #
        # @return [Hash] Empty result hash
        def empty_result
          {
            classes: [],
            attributes: [],
            associations: [],
            total: 0,
          }
        end

        # Return empty full text search result
        #
        # @return [Hash] Empty result hash
        def empty_full_text_search_result
          {
            classes: [],
            packages: [],
            total: 0,
          }
        end
      end
    end
  end
end
