# frozen_string_literal: true

require "thor"
require_relative "base_command"

module Lutaml
  module Xsd
    module Commands
      # Thor subcommand for displaying repository statistics
      class StatsCommand < Thor
        # Command aliases
        map "s" => :show

        class_option :verbose,
                     type: :boolean,
                     default: false,
                     desc: "Enable verbose output"

        desc "show PATH",
             "Display statistics for a schema repository package"
        long_desc <<~DESC
          Display comprehensive statistics for a schema repository package (.lxr file).

          The statistics include:
          - Total number of schemas parsed
          - Total number of types indexed
          - Types breakdown by category (complex, simple, element, attribute, etc.)
          - Total number of namespaces

          Examples:
            # Display statistics for a package
            lutaml-xsd stats show pkg/my_schemas.lxr

            # Display statistics in JSON format
            lutaml-xsd stats show pkg/my_schemas.lxr --format json

            # Display statistics with verbose output
            lutaml-xsd stats show pkg/my_schemas.lxr --verbose
        DESC
        option :format,
               type: :string,
               enum: %w[text json yaml],
               default: "text",
               desc: "Output format (text, json, yaml)"
        def show(path)
          ShowCommand.new(path, options).run
        end

        # Command class for showing repository statistics
        class ShowCommand < BaseCommand
          def initialize(path, options = {})
            super(options)
            @path = path
            @format = options[:format] || "text"
          end

          def run
            repository = load_repository(@path)
            ensure_resolved(repository)

            stats = repository.statistics
            output_statistics(stats)
          rescue StandardError => e
            error("Failed to display statistics: #{e.message}")
            verbose_output(e.backtrace.join("\n")) if verbose?
            raise CommandError
          end

          private

          def output_statistics(stats)
            case @format
            when "json"
              output_json(stats)
            when "yaml"
              output_yaml(stats)
            else
              output_text(stats)
            end
          end

          def output_text(stats)
            require "table_tennis"

            output "Repository Statistics:"
            output "=" * 80
            output ""
            output "Total schemas parsed: #{stats[:total_schemas]}"
            output "Total types indexed: #{stats[:total_types]}"
            output "Total namespaces: #{stats[:total_namespaces]}"
            output ""
            output "Types by category:"
            output "-" * 80

            # Build table data as array of hashes
            category_data = stats[:types_by_category].sort.map do |category, count|
              { "Category" => category.to_s, "Count" => count }
            end

            category_table = TableTennis.new(category_data)
            output category_table
          end

          def output_json(stats)
            require "json"
            output JSON.pretty_generate(stats)
          end

          def output_yaml(stats)
            require "yaml"
            output stats.to_yaml
          end
        end
      end
    end
  end
end
