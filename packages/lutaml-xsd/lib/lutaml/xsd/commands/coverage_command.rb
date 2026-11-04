# frozen_string_literal: true

require_relative "base_command"

module Lutaml
  module Xsd
    module Commands
      # Command for analyzing schema coverage from entry points
      # Shows which types are reachable from specified entry types
      class CoverageCommand < BaseCommand
        def initialize(package_path, options)
          super(options)
          @package_path = package_path
          @entry_types = parse_entry_types(options[:entry])
          @format = options[:format] || "text"
        end

        def run
          validate_package_exists
          perform_coverage_analysis
        end

        private

        def validate_package_exists
          return if File.exist?(@package_path)

          error "Package file not found: #{@package_path}"
          raise CommandError
        end

        def parse_entry_types(entry_option)
          return [] unless entry_option

          # Split by comma and trim whitespace
          entry_option.split(",").map(&:strip).reject(&:empty?)
        end

        def perform_coverage_analysis
          verbose_output "Loading package: #{@package_path}"
          repository = load_repository(@package_path)
          ensure_resolved(repository)

          if @entry_types.empty?
            error "No entry types specified. Use --entry to specify entry point types."
            error 'Example: --entry "gml:Point,gml:LineString"'
            raise CommandError
          end

          verbose_output "Analyzing coverage from #{@entry_types.size} entry type(s)..."
          verbose_output "Entry types: #{@entry_types.join(', ')}"

          # Perform coverage analysis
          report = repository.analyze_coverage(entry_types: @entry_types)

          # Display results
          display_results(report)
        rescue StandardError => e
          error "Coverage analysis failed: #{e.message}"
          verbose_output e.backtrace.join("\n") if verbose?
          raise CommandError
        end

        def display_results(report)
          case @format
          when "json"
            output_json(report)
          when "yaml"
            output_yaml(report)
          else
            output_text(report)
          end
        end

        def output_json(report)
          require "json"
          output JSON.pretty_generate(report.to_h)
        end

        def output_yaml(report)
          require "yaml"
          output report.to_h.to_yaml
        end

        def output_text(report)
          require "table_tennis"

          output "=" * 80
          output "Schema Coverage Analysis"
          output "=" * 80
          output ""

          # Summary section
          output "Summary:"
          output "  Entry Types: #{report.entry_types.join(', ')}"
          output "  Total Types: #{report.total_types}"
          output "  Used Types: #{report.used_count}"
          output "  Unused Types: #{report.unused_count}"
          output "  Coverage: #{report.coverage_percentage}%"
          output ""

          # Coverage by namespace
          output_namespace_coverage(report)

          # Unused types (if any)
          if report.unused_count.positive?
            output ""
            output_unused_types(report)
          end

          output ""
          output "=" * 80
        end

        def output_namespace_coverage(report)
          output "-" * 80
          output "Coverage by Namespace"
          output "-" * 80

          # Build table data
          namespace_data = report.by_namespace.map do |ns, data|
            {
              "Namespace" => truncate_namespace(ns),
              "Total" => data[:total],
              "Used" => data[:used],
              "Unused" => data[:total] - data[:used],
              "Coverage %" => data[:coverage_percentage],
            }
          end.sort_by { |row| -row["Coverage %"] }

          if namespace_data.any?
            table = TableTennis.new(namespace_data)
            output table
          else
            output "  (no namespaces)"
          end
        end

        def output_unused_types(report)
          output "-" * 80
          output "Unused Types (#{report.unused_count})"
          output "-" * 80

          # Group unused types by namespace
          unused_by_ns = {}
          report.by_namespace.each do |ns, data|
            unused_in_ns = data[:types].reject { |t| t[:used] }
            unused_by_ns[ns] = unused_in_ns if unused_in_ns.any?
          end

          # Display each namespace's unused types
          unused_by_ns.each do |ns, types|
            output ""
            output "#{truncate_namespace(ns)} (#{types.size} unused):"

            # Build table for this namespace
            type_data = types.map do |type_info|
              {
                "Type Name" => type_info[:name] || "(anonymous)",
                "Category" => type_info[:category].to_s,
              }
            end.sort_by { |row| row["Type Name"] }

            # Limit display to first 20 types per namespace
            if type_data.size > 20
              displayed = type_data.first(20)
              table = TableTennis.new(displayed)
              output table
              output "  ... and #{type_data.size - 20} more"
            else
              table = TableTennis.new(type_data)
              output table
            end
          end
        end

        def truncate_namespace(namespace)
          return namespace if namespace.length <= 50

          "...#{namespace[-47..]}"
        end
      end
    end
  end
end
