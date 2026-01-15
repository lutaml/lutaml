# frozen_string_literal: true

require_relative "../output_formatter"
require_relative "shared_helpers"

module Lutaml
  module Cli
    module Uml
      # FindCommand finds elements by criteria
      class FindCommand
        include SharedHelpers

        attr_reader :options

        def initialize(options = {})
          @options = options.transform_keys(&:to_sym)
        end

        def self.add_options_to(thor_class, _method_name)
          thor_class.long_desc <<-DESC
          Find elements matching specific criteria.

          Examples:
            lutaml uml find model.lur --stereotype interface
            lutaml uml find model.lur --package ModelRoot::Core
            lutaml uml find model.lur --pattern "^Building.*"
          DESC

          thor_class.option :stereotype, type: :string,
                                         desc: "Filter by stereotype"
          thor_class.option :package, type: :string, desc: "Filter by package"
          thor_class.option :pattern, type: :string, desc: "Match name pattern"
          thor_class.option :format, type: :string, default: "text",
                                     desc: "Output format (text|yaml|json)"
          thor_class.option :lazy, type: :boolean, default: false,
                                   desc: "Use lazy loading"
        end

        def run(lur_path)
          validate_options!

          # Load the repository from the LUR file
          repo = load_repository(lur_path, lazy: options[:lazy])

          # Get results based on the filter type
          results = if options[:pattern] # e.g. "^Building.*"
                      types = [ options[:type] || :class ]
                      repo.search(options[:pattern], types: types)
                    elsif options[:stereotype]
                      repo.find_classes_by_stereotype(options[:stereotype])
                    elsif options[:package]
                      repo.classes_in_package(options[:package], recursive: false)
                    else
                      []
                    end

          # Extract classes from the nested structure
          classes = case results
                    when Array
                      if results.length == 2 && results[0] == :classes
                        results[1]  # Extract the actual classes array
                      else
                        results     # Assume it's already an array of classes
                      end
                    when NilClass
                      []
                    else
                      [results]     # Wrap single result in array
                    end

          if classes.nil? || classes.empty?
            filter_desc = options[:pattern] ? "pattern: #{options[:pattern]}" :
                          options[:stereotype] ? "stereotype: #{options[:stereotype]}" :
                          options[:package] ? "package: #{options[:package]}" : "criteria"
            puts "No elements found matching #{filter_desc}"
            return
          end

          output = classes.map { |cls| cls.respond_to?(:name) ? (cls.name || cls.to_s) : cls.to_s }

          # output result based on the format option
          case options[:format]
          when "json"
            puts output.to_json
          when "yaml"
            puts output.to_yaml
          else
            puts output.join("\n")
          end
        rescue Thor::Error
          raise
        rescue ArgumentError => e
          raise Thor::Error, e.message
        rescue StandardError => e
          raise Thor::Error, "Find command failed: #{e.message}"
        end

        private

        def validate_options!
          # At least one filter option must be specified
          unless options[:pattern] || options[:stereotype] || options[:package]
            puts "Please specify at least one filter: --pattern, --stereotype, or --package"
            raise Thor::Error, "Please specify at least one filter: --pattern, --stereotype, or --package"
          end
        end
      end
    end
  end
end
