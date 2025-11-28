# frozen_string_literal: true

require_relative "../output_formatter"
require_relative "shared_helpers"

module Lutaml
  module Cli
    module Uml
      # StatsCommand shows repository statistics
      class StatsCommand
        include SharedHelpers

        attr_reader :options

        def initialize(options = {})
          @options = options.transform_keys(&:to_sym)
        end

        def self.add_options_to(thor_class, _method_name)
          thor_class.long_desc <<-DESC
          Display statistics about the repository or a specific package.

          Examples:
            lutaml uml stats model.lur                  # Full repository stats
            lutaml uml stats model.lur --detailed       # Detailed breakdown
            lutaml uml stats model.lur --type diagrams  # Diagram-specific stats
          DESC

          thor_class.option :type, type: :string, default: "all",
                                   desc: "Statistics type (packages|classes|diagrams|all)"
          thor_class.option :detailed, type: :boolean, default: false,
                                       desc: "Show detailed statistics"
          thor_class.option :format, type: :string, default: "text",
                                     desc: "Output format (text|yaml|json)"
          thor_class.option :lazy, type: :boolean, default: false,
                                   desc: "Use lazy loading"
        end

        def run(lur_path, _path = nil)
          repo = load_repository(lur_path, lazy: options[:lazy])
          statistics = repo.statistics

          if options[:format] == "text"
            puts OutputFormatter.format_stats(statistics,
                                              detailed: options[:detailed])
          else
            puts OutputFormatter.format(statistics, format: options[:format])
          end
        rescue Thor::Error
          raise
        rescue ArgumentError => e
          raise Thor::Error, e.message
        rescue StandardError => e
          raise Thor::Error, "Stats command failed: #{e.message}"
        end
      end
    end
  end
end
