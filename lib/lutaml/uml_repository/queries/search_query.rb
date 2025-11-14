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
      #   # => { classes: [...], attributes: [...], associations: [...], total: 15 }
      #
      # @example Pattern matching
      #   results = query.by_pattern(/^Urban/, type: :class)
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
        # @param fields [Array<Symbol>] Fields to search in - :name, :documentation
        #   (default: [:name])
        # @return [Hash] Search results with keys :classes, :attributes,
        #   :associations, :total
        # @example
        #   results = query.search("building")
        #   results = query.search("urban", fields: [:name, :documentation])
        def search(query_string, types: %i[class attribute association],
fields: [:name])
          return empty_result if query_string.nil? || query_string.empty?

          query_lower = query_string.downcase
          results = {
            classes: [],
            attributes: [],
            associations: [],
            total: 0,
          }

          # Search classes
          if types.include?(:class)
            results[:classes] = search_classes(query_lower, fields: fields)
          end

          # Search attributes
          if types.include?(:attribute)
            results[:attributes] =
              search_attributes(query_lower, fields: fields)
          end

          # Search associations
          if types.include?(:association)
            results[:associations] =
              search_associations(query_lower, fields: fields)
          end

          results[:total] = results[:classes].size +
            results[:attributes].size +
            results[:associations].size

          results
        end

        # Search using a regex pattern returning SearchResult objects.
        #
        # Similar to search but uses regex pattern matching. Returns results
        # in the same SearchResult format for consistency with text search.
        #
        # @param pattern [String, Regexp] The regex pattern to match
        # @param types [Array<Symbol>] Types to search in - :class, :attribute,
        #   :association (default: [:class, :attribute, :association])
        # @param fields [Array<Symbol>] Fields to search in (:name, :documentation)
        #   (default: [:name])
        # @return [Hash] Search results with keys :classes, :attributes,
        #   :associations, :total
        # @example
        #   results = query.search_by_pattern("^Building.*")
        #   results = query.search_by_pattern("urban", fields: [:documentation])
        def search_by_pattern(pattern,
types: %i[class attribute association], fields: [:name])
          regex = pattern.is_a?(Regexp) ? pattern : Regexp.new(pattern)
          results = {
            classes: [],
            attributes: [],
            associations: [],
            total: 0,
          }

          # Search classes
          if types.include?(:class)
            results[:classes] = pattern_search_classes(regex, fields: fields)
          end

          # Search attributes
          if types.include?(:attribute)
            results[:attributes] =
              pattern_search_attributes(regex, fields: fields)
          end

          # Search associations
          if types.include?(:association)
            results[:associations] =
              pattern_search_associations(regex, fields: fields)
          end

          results[:total] = results[:classes].size +
            results[:attributes].size +
            results[:associations].size

          results
        end

        # Search using a regex pattern.
        #
        # @param pattern [Regexp, String] The regex pattern to match. If a
        #   string is provided, it will be converted to a regex.
        # @param type [Symbol] Type to search - :class, :attribute, or :association
        # @return [Hash] Search results with keys :classes, :attributes,
        #   :associations, :total
        # @example
        #   results = query.by_pattern(/^Urban/, type: :class)
        #   # => {
        #   #   classes: [Class{name: "UrbanArea"}, Class{name: "UrbanPlan"}, ...],
        #   #   attributes: [],
        #   #   associations: [],
        #   #   total: 2
        #   # }
        def by_pattern(pattern, type: :class)
          regex = pattern.is_a?(Regexp) ? pattern : Regexp.new(pattern)
          results = {
            classes: [],
            attributes: [],
            associations: [],
            total: 0,
          }

          case type
          when :class
            results[:classes] = pattern_match_classes(regex)
          when :attribute
            results[:attributes] = pattern_match_attributes(regex)
          when :association
            results[:associations] = pattern_match_associations(regex)
          end

          results[:total] = results[:classes].size +
            results[:attributes].size +
            results[:associations].size

          results
        end

        private

        # Search for classes matching the query
        #
        # @param query_lower [String] Lowercase query string
        # @param fields [Array<Symbol>] Fields to search in
        # @return [Array<SearchResult>] Matching search result objects
        def search_classes(query_lower, fields: [:name])
          indexes[:qualified_names].map do |qname, klass|
            match_field = nil

            # Check name field
            if fields.include?(:name) && klass.name&.downcase&.include?(query_lower)
              match_field = :name
            end

            # Check documentation field
            if !match_field && fields.include?(:documentation) && klass.respond_to?(:documentation) &&
                klass.documentation&.downcase&.include?(query_lower)
              match_field = :documentation
            end

            next unless match_field

            SearchResult.new(
              element: klass,
              element_type: :class,
              qualified_name: qname,
              package_path: extract_package_path(qname),
              match_field: match_field,
            )
          end.compact.uniq { |r| r.element.object_id }
        end

        # Search for attributes matching the query
        #
        # @param query_lower [String] Lowercase query string
        # @param fields [Array<Symbol>] Fields to search in
        # @return [Array<SearchResult>] Matching search result objects
        def search_attributes(query_lower, fields: [:name])
          results = []

          indexes[:qualified_names].each do |class_qname, klass|
            next unless klass.respond_to?(:attributes) && klass.attributes

            klass.attributes.each do |attr|
              match_field = nil

              # Check name field
              if fields.include?(:name) && attr.name&.downcase&.include?(query_lower)
                match_field = :name
              end

              # Check documentation field
              if !match_field && fields.include?(:documentation) && attr.respond_to?(:documentation) &&
                  attr.documentation&.downcase&.include?(query_lower)
                match_field = :documentation
              end

              next unless match_field

              results << SearchResult.new(
                element: attr,
                element_type: :attribute,
                qualified_name: "#{class_qname}::#{attr.name}",
                package_path: extract_package_path(class_qname),
                match_field: match_field,
                match_context: {
                  "class_name" => klass.name,
                  "class_qname" => class_qname,
                },
              )
            end
          end

          results
        end

        # Search for associations matching the query
        #
        # @param query_lower [String] Lowercase query string
        # @param fields [Array<Symbol>] Fields to search in
        # @return [Array<SearchResult>] Matching search result objects
        def search_associations(query_lower, fields: [:name])
          results = []

          # Search in document-level associations
          if document.respond_to?(:associations) && document.associations
            document.associations.each do |assoc|
              match_field = match_association_fields?(assoc, query_lower,
                                                      fields)
              next unless match_field

              results << SearchResult.new(
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
          end

          # Search in class-level associations
          indexes[:qualified_names].each_value do |klass|
            next unless klass.respond_to?(:associations) && klass.associations

            klass.associations.each do |assoc|
              match_field = match_association_fields?(assoc, query_lower,
                                                      fields)
              next unless match_field

              results << SearchResult.new(
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
          end

          results.uniq { |r| r.element.object_id }
        end

        # Pattern match for classes
        #
        # @param regex [Regexp] Regular expression pattern
        # @return [Array] Matching class objects
        def pattern_match_classes(regex)
          indexes[:qualified_names].values.select do |klass|
            klass.name&.match?(regex)
          end.uniq
        end

        # Pattern match for attributes
        #
        # @param regex [Regexp] Regular expression pattern
        # @return [Array] Matching attribute objects
        def pattern_match_attributes(regex)
          results = []

          indexes[:qualified_names].each_value do |klass|
            next unless klass.respond_to?(:attributes) && klass.attributes

            klass.attributes.each do |attr|
              if attr.name&.match?(regex)
                results << attr
              end
            end
          end

          results
        end

        # Pattern match for associations
        #
        # @param regex [Regexp] Regular expression pattern
        # @return [Array] Matching association objects
        def pattern_match_associations(regex)
          results = []

          # Search in document-level associations
          if document.respond_to?(:associations) && document.associations
            document.associations.each do |assoc|
              if match_association_pattern?(assoc, regex)
                results << assoc
              end
            end
          end

          # Search in class-level associations
          indexes[:qualified_names].each_value do |klass|
            next unless klass.respond_to?(:associations) && klass.associations

            klass.associations.each do |assoc|
              if match_association_pattern?(assoc, regex)
                results << assoc
              end
            end
          end

          results.uniq
        end

        # Check if association matches text query in specified fields
        #
        # @param assoc [Lutaml::Uml::Association] Association object
        # @param query_lower [String] Lowercase query string
        # @param fields [Array<Symbol>] Fields to search in
        # @return [Symbol, nil] Matched field or nil
        def match_association_fields?(assoc, query_lower, fields)
          # Check name fields (includes owner_end and member_end)
          if fields.include?(:name) && (assoc.owner_end&.downcase&.include?(query_lower) ||
                assoc.member_end&.downcase&.include?(query_lower) ||
                assoc.owner_end_attribute_name&.downcase&.include?(query_lower) ||
                assoc.member_end_attribute_name&.downcase&.include?(query_lower))
            return :name
          end

          # Check documentation field
          if fields.include?(:documentation) && assoc.respond_to?(:documentation) &&
              assoc.documentation&.downcase&.include?(query_lower)
            return :documentation
          end

          false
        end

        # Check if association matches pattern in specified fields
        #
        # @param assoc [Lutaml::Uml::Association] Association object
        # @param regex [Regexp] Regular expression pattern
        # @param fields [Array<Symbol>] Fields to search in
        # @return [Symbol, nil] Matched field or nil
        def match_association_pattern_fields?(assoc, regex, fields)
          # Check name fields
          if fields.include?(:name) && (assoc.owner_end&.match?(regex) ||
                assoc.member_end&.match?(regex) ||
                assoc.owner_end_attribute_name&.match?(regex) ||
                assoc.member_end_attribute_name&.match?(regex))
            return :name
          end

          # Check documentation field
          if fields.include?(:documentation) && assoc.respond_to?(:documentation) && assoc.documentation&.match?(regex)
            return :documentation
          end

          false
        end

        # Pattern search for classes returning SearchResult objects
        #
        # @param regex [Regexp] Regular expression pattern
        # @param fields [Array<Symbol>] Fields to search in
        # @return [Array<SearchResult>] Matching search result objects
        def pattern_search_classes(regex, fields: [:name])
          indexes[:qualified_names].map do |qname, klass|
            match_field = nil

            # Check name field
            if fields.include?(:name) && klass.name&.match?(regex)
              match_field = :name
            end

            # Check documentation field
            if !match_field && fields.include?(:documentation) && klass.respond_to?(:documentation) && klass.documentation&.match?(regex)
              match_field = :documentation
            end

            next unless match_field

            SearchResult.new(
              element: klass,
              element_type: :class,
              qualified_name: qname,
              package_path: extract_package_path(qname),
              match_field: match_field,
            )
          end.compact.uniq { |r| r.element.object_id }
        end

        # Pattern search for attributes returning SearchResult objects
        #
        # @param regex [Regexp] Regular expression pattern
        # @param fields [Array<Symbol>] Fields to search in
        # @return [Array<SearchResult>] Matching search result objects
        def pattern_search_attributes(regex, fields: [:name])
          results = []

          indexes[:qualified_names].each do |class_qname, klass|
            next unless klass.respond_to?(:attributes) && klass.attributes

            klass.attributes.each do |attr|
              match_field = nil

              # Check name field
              if fields.include?(:name) && attr.name&.match?(regex)
                match_field = :name
              end

              # Check documentation field
              if !match_field && fields.include?(:documentation) && attr.respond_to?(:documentation) && attr.documentation&.match?(regex)
                match_field = :documentation
              end

              next unless match_field

              results << SearchResult.new(
                element: attr,
                element_type: :attribute,
                qualified_name: "#{class_qname}::#{attr.name}",
                package_path: extract_package_path(class_qname),
                match_field: match_field,
                match_context: {
                  "class_name" => klass.name,
                  "class_qname" => class_qname,
                },
              )
            end
          end

          results
        end

        # Pattern search for associations returning SearchResult objects
        #
        # @param regex [Regexp] Regular expression pattern
        # @param fields [Array<Symbol>] Fields to search in
        # @return [Array<SearchResult>] Matching search result objects
        def pattern_search_associations(regex, fields: [:name])
          results = []

          # Search in document-level associations
          if document.respond_to?(:associations) && document.associations
            document.associations.each do |assoc|
              match_field = match_association_pattern_fields?(assoc, regex,
                                                              fields)
              next unless match_field

              results << SearchResult.new(
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
          end

          # Search in class-level associations
          indexes[:qualified_names].each_value do |klass|
            next unless klass.respond_to?(:associations) && klass.associations

            klass.associations.each do |assoc|
              match_field = match_association_pattern_fields?(assoc, regex,
                                                              fields)
              next unless match_field

              results << SearchResult.new(
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
          end

          results.uniq { |r| r.element.object_id }
        end

        # Extract package path from qualified name
        #
        # @param qualified_name [String] Qualified name (e.g., "pkg1::pkg2::Class")
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
      end
    end
  end
end
