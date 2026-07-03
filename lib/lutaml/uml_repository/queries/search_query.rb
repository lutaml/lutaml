# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module Queries
      class SearchQuery < BaseQuery
        include Lutaml::Uml::ModelHelpers

        RESULT_KEYS = {
          class: :classes,
          attribute: :attributes,
          association: :associations,
        }.freeze

        FIELD_READERS = {
          name: lambda(&:name),
          documentation: lambda(&:documentation),
          owner_end: lambda(&:owner_end),
          member_end: lambda(&:member_end),
          owner_end_attribute_name: lambda(&:owner_end_attribute_name),
          member_end_attribute_name: lambda(&:member_end_attribute_name),
        }.freeze

        def search(query_string, types: %i[class attribute association],
                          fields: [:name], case_sensitive: false)
          return empty_result if query_string.nil? || query_string.empty?

          results = { classes: [], attributes: [], associations: [] }
          types.each do |type|
            key = RESULT_KEYS[type]
            results[key] = dispatch_search(
              type, query_string,
              fields: fields, case_sensitive: case_sensitive
            )
          end
          results[:total] =
            results.values_at(:classes, :attributes, :associations).sum(&:size)
          results
        end

        def full_text_search(query_string, fields: [:name],
case_sensitive: false)
          results = { classes: [], packages: [], total: 0 }
          return results if query_string.nil? || query_string.empty?

          results[:classes] = search_classes(
            query_string, fields: fields, case_sensitive: case_sensitive
          )
          results[:packages] = search_packages(
            query_string, case_sensitive: case_sensitive
          )
          results[:total] = results[:classes].size + results[:packages].size
          results
        end

        def search_classes(query, fields: %i[name documentation],
                                case_sensitive: false)
          pattern = pattern_from(query, case_sensitive)

          indexes[:qualified_names].filter_map do |qname, entity|
            next unless entity.is_a?(Lutaml::Uml::Class)

            match_field = first_matching_field(entity, fields, pattern)
            next unless match_field

            build_search_result(entity, :class, qname, match_field)
          end.uniq
        end

        def search_attributes(query, fields: [:name],
                                     case_sensitive: false)
          pattern = pattern_from(query, case_sensitive)

          indexes[:qualified_names].filter_map do |class_qname, entity|
            next unless entity.is_a?(Lutaml::Uml::Classifier) && entity.attributes

            attr_match = find_matching_attribute(entity, fields, pattern)
            next unless attr_match

            attr, match_field = attr_match
            build_search_result(
              attr, :attribute,
              "#{class_qname}::#{attr.name}", match_field,
              { "class_name" => entity.name, "class_qname" => class_qname },
              package_path: extract_package_path(class_qname)
            )
          end.uniq
        end

        def search_associations(query,
                                fields: %i[
                                  name owner_end member_end
                                  owner_end_attribute_name
                                  member_end_attribute_name documentation
                                ],
                                case_sensitive: false)
          pattern = pattern_from(query, case_sensitive)

          get_all_associations.filter_map do |assoc|
            match_field = first_matching_field(assoc, fields, pattern)
            next unless match_field

            build_search_result(
              assoc, :association,
              assoc.name || "(unnamed)", match_field,
              { "source" => assoc.owner_end, "target" => assoc.member_end }
            )
          end.uniq
        end

        def search_by_stereotype(query, case_sensitive: false)
          pattern = pattern_from(query, case_sensitive)

          find_entities_by_stereotype_pattern(pattern).map do |entity|
            build_search_result(
              entity,
              entity.class.name.split("::").last.downcase.to_sym,
              "", :stereotype
            )
          end
        end

        def search_packages(query, case_sensitive: false)
          pattern = pattern_from(query, case_sensitive)

          indexes[:package_paths].filter_map do |path_string, package|
            next unless path_string.to_s.match?(pattern)

            build_search_result(package, :package, path_string, :package_path,
                                package_path: path_string)
          end
        end

        def get_all_associations
          all_associations = []

          if document.is_a?(Lutaml::Uml::Document) && document.associations
            all_associations << document.associations
          end

          indexes[:qualified_names].each_value do |entity|
            next unless classifiable_with_associations?(entity)

            all_associations << entity.associations
          end

          all_associations.flatten.uniq
        end

        private

        def pattern_from(query, case_sensitive)
          query = query.gsub("*", ".*") unless query.include?(".*")
          Regexp.new(query, case_sensitive ? 0 : Regexp::IGNORECASE)
        end

        def field_value_matches?(obj, field, pattern)
          return false unless obj.class.attributes.key?(field)

          read_attribute(obj, field)&.match?(pattern)
        end

        def first_matching_field(entity, fields, pattern)
          fields.reverse_each.find do |f|
            field_value_matches?(entity, f, pattern)
          end
        end

        def find_matching_attribute(entity, fields, pattern)
          result = nil
          entity.attributes.each do |attr|
            fields.each do |field|
              result = [attr, field] if field_value_matches?(attr, field,
                                                             pattern)
            end
          end
          result
        end

        def build_search_result(entity, type, qname, match_field,
                                context = {}, **extra)
          SearchResult.new(
            element: entity,
            element_type: type,
            qualified_name: qname,
            package_path: extra[:package_path] || extract_package_path(qname),
            match_field: match_field,
            match_context: context,
          )
        end

        def classifiable_with_associations?(entity)
          entity.is_a?(Lutaml::Uml::Class) || entity.is_a?(Lutaml::Uml::DataType)
        end

        def find_entities_by_stereotype_pattern(pattern)
          indexes[:stereotypes]
            .filter_map do |_stereotype, entities|
            entities.select do |entity|
              entity.is_a?(Lutaml::Uml::Classifier) &&
                Array(entity.stereotype).any? { |s| s&.match?(pattern) }
            end.uniq
          end.uniq.flatten
        end

        def empty_result
          { classes: [], attributes: [], associations: [], total: 0 }
        end

        def dispatch_search(type, query_string, fields:, case_sensitive:)
          case type
          when :class
            search_classes(query_string,
                           fields: fields,
                           case_sensitive: case_sensitive)
          when :attribute
            search_attributes(query_string,
                              fields: fields,
                              case_sensitive: case_sensitive)
          when :association
            search_associations(query_string,
                                fields: fields,
                                case_sensitive: case_sensitive)
          end
        end

        def read_attribute(obj, field)
          reader = FIELD_READERS[field]
          return nil unless reader

          reader.call(obj)
        end
      end
    end
  end
end
