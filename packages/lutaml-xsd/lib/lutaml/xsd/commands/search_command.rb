# frozen_string_literal: true

require_relative "base_command"
require_relative "../type_searcher"

module Lutaml
  module Xsd
    module Commands
      # Search command implementation
      # Searches for types by name or documentation with relevance ranking
      class SearchCommand < BaseCommand
        def initialize(query, package_path, options)
          super(options)
          @query = query
          @package_path = package_path
        end

        def run
          repository = load_repository(@package_path)
          repository = ensure_resolved(repository)

          # Store package root for path display
          @package_root = if @package_path.end_with?(".lxr")
                            # For LXR packages, get the temp extraction dir
                            repository.instance_variable_get(:@temp_extraction_dir) || Dir.pwd
                          else
                            # For other formats, use parent directory of first file
                            repository.files&.first ? File.dirname(repository.files.first) : Dir.pwd
                          end

          search_and_display(repository)
        end

        private

        def search_and_display(repository)
          verbose_output "Searching for: #{@query}"
          verbose_output "  Search field: #{options[:in] || 'both'}"
          verbose_output "  Namespace filter: #{options[:namespace] || 'none'}"
          verbose_output "  Category filter: #{options[:category] || 'none'}"
          verbose_output "  Result limit: #{options[:limit] || 20}"
          verbose_output ""

          # Create searcher
          searcher = TypeSearcher.new(repository)

          # Perform search
          results = searcher.search(
            @query,
            in_field: options[:in] || "both",
            namespace: options[:namespace],
            category: options[:category],
            limit: options[:limit] || 20,
          )

          # Display results
          format = options[:format] || "text"

          case format
          when "json"
            output format_output(format_results_for_json(results), format)
          when "yaml"
            output format_output(format_results_for_yaml(results), format)
          else
            display_text_results(results)
          end
        end

        def display_text_results(results)
          require "table_tennis"

          output "=" * 80
          output "Search Results: \"#{@query}\""
          output "=" * 80
          output ""

          if results.empty?
            output "No types found matching your search criteria."
            output ""
            output "Tips:"
            output "  - Try searching with --in both (default) to search name and documentation"
            output "  - Remove namespace or category filters to broaden results"
            output "  - Try a shorter or more general search term"
            return
          end

          output "Found #{results.size} type(s)"
          output ""

          # Group results by match type for better display
          by_match_type = results.group_by(&:match_type)

          # Display in order of relevance
          match_type_order = %w[
            exact_name
            name_starts_with
            name_contains
            doc_exact_word
            doc_contains
          ]

          match_type_order.each do |match_type|
            next unless by_match_type[match_type]

            display_match_group(match_type, by_match_type[match_type])
          end

          output ""
          output "💡 Use 'lutaml-xsd type find <qname> #{@package_path}' to view details"
        end

        def display_match_group(match_type, results)
          output match_type_label(match_type)
          output "-" * 80
          output ""

          results.each do |result|
            display_search_result(result)
          end

          output ""
        end

        def display_search_result(result)
          require "table_tennis"

          # Get schema file with package path
          schema_file = if result.schema_file
                          # Show relative path within package
                          result.schema_file.sub(@package_root, "").sub(%r{^/},
                                                                        "")
                        else
                          "(unknown)"
                        end

          # Build result data
          result_data = [
            { "Property" => "Qualified Name",
              "Value" => result.qualified_name },
            { "Property" => "Category", "Value" => result.category.to_s },
            { "Property" => "Namespace",
              "Value" => result.namespace || "(none)" },
            { "Property" => "Schema File", "Value" => schema_file },
            { "Property" => "Relevance",
              "Value" => "#{result.relevance_score} (#{result.match_type})" },
          ]

          # Add annotation if present (renamed from "Documentation")
          if result.documentation && !result.documentation.empty?
            doc_preview = if result.documentation.length > 200
                            "#{result.documentation[0..197]}..."
                          else
                            result.documentation
                          end
            result_data << { "Property" => "Annotation",
                             "Value" => doc_preview }
          end

          table = TableTennis.new(result_data)
          output table
          output ""
        end

        def match_type_label(match_type)
          case match_type
          when "exact_name"
            "Exact Name Match"
          when "name_starts_with"
            "Name Starts With"
          when "name_contains"
            "Name Contains"
          when "doc_exact_word"
            "Documentation Exact Word Match"
          when "doc_contains"
            "Documentation Contains"
          else
            "Other Matches"
          end
        end

        def format_results_for_json(results)
          {
            query: @query,
            search_field: options[:in] || "both",
            namespace_filter: options[:namespace],
            category_filter: options[:category],
            limit: options[:limit] || 20,
            total_results: results.size,
            results: results.map(&:to_h),
          }
        end

        def format_results_for_yaml(results)
          format_results_for_json(results)
        end
      end
    end
  end
end
