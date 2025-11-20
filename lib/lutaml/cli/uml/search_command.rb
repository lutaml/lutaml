# frozen_string_literal: true

require_relative "../output_formatter"
require_relative "shared_helpers"

module Lutaml
  module Cli
    module Uml
      # SearchCommand performs full-text search in model
      class SearchCommand
        include SharedHelpers

        attr_reader :options

        def initialize(options = {})
          @options = options.transform_keys(&:to_sym)
        end

        def self.add_options_to(thor_class, _method_name)
          thor_class.long_desc <<-DESC
          Perform full-text search across model elements.

          Examples:
            lutaml uml search model.lur "building"
            lutaml uml search model.lur "building" --type class
            lutaml uml search model.lur "^Building" --regex
            lutaml uml search model.lur "urban" --in name documentation
          DESC

          thor_class.option :type, type: :array,
                                   default: ["class", "attribute", "association"],
                                   desc: "Types to search"
          thor_class.option :package, type: :string,
                                      desc: "Filter by package path"
          thor_class.option :regex, type: :boolean, default: false,
                                    desc: "Treat query as regex"
          thor_class.option :in, type: :array, default: ["name"],
                                 desc: "Search in fields (name, documentation)"
          thor_class.option :format, type: :string, default: "table",
                                     desc: "Output format (text|table|yaml|json)"
          thor_class.option :limit, type: :numeric, default: 100,
                                    desc: "Maximum results"
          thor_class.option :lazy, type: :boolean, default: false,
                                   desc: "Use lazy loading"
        end

        def run(lur_path, query)
          repo = load_repository(lur_path, lazy: options[:lazy])
          types = options[:type].map(&:to_sym)
          search_fields = options[:in].map(&:to_sym)

          results = if options[:regex]
                      repo.search_by_pattern(query, types: types,
                                                    fields: search_fields)
                    else
                      repo.search(query, types: types, fields: search_fields)
                    end

          display_search_results(results, query, repo)
        end

        private

        def display_search_results(results, query, _repo)
          all_results = []
          all_results.concat(results[:classes] || [])
          all_results.concat(results[:attributes] || [])
          all_results.concat(results[:associations] || [])

          if all_results.empty?
            puts OutputFormatter.warning("No results found for '#{query}'")
            return
          end

          if options[:format] == "table"
            table_data = all_results.map do |search_result|
              {
                type: search_result.element_type,
                name: search_result.qualified_name,
                package: search_result.package_path,
              }
            end
            puts OutputFormatter.format_array_table(table_data)
          else
            data = all_results.map(&:to_yaml_hash)
            puts OutputFormatter.format(data, format: options[:format])
          end
        end
      end
    end
  end
end
