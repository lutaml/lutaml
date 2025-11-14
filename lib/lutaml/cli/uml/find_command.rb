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
          @options = options
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
          repo = load_repository(lur_path, lazy: options[:lazy])

          results = if options[:stereotype]
                      repo.find_classes_by_stereotype(options[:stereotype])
                    elsif options[:package]
                      repo.classes_in_package(options[:package])
                    elsif options[:pattern]
                      pattern = Regexp.new(options[:pattern])
                      repo.find_by_pattern(pattern, type: :class)
                    else
                      puts OutputFormatter.error("Please specify at least one filter")
                      exit 1
                    end

          if results.empty?
            puts OutputFormatter.warning("No results found")
            return
          end

          output = results.map { |cls| cls.name || cls.to_s }
          puts OutputFormatter.format(output, format: options[:format])
        end
      end
    end
  end
end
