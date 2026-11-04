# frozen_string_literal: true

require_relative "base_command"
require_relative "../interactive_builder"

module Lutaml
  module Xsd
    module Commands
      # Initialize package with interactive dependency resolution
      class InitCommand < BaseCommand
        attr_reader :entry_points

        def initialize(entry_points, options)
          super(options)
          @entry_points = entry_points
        end

        def run
          validate_entry_points
          run_interactive_builder
        end

        private

        def validate_entry_points
          if entry_points.empty?
            error "No entry points specified"
            error "Usage: lutaml-xsd package init ENTRY_POINTS [options]"
            raise CommandError
          end

          entry_points.each do |entry_point|
            next if File.exist?(entry_point)

            error "Entry point not found: #{entry_point}"
            raise CommandError
          end
        end

        def run_interactive_builder
          builder = InteractiveBuilder.new(entry_points, options)
          success = builder.run

          unless success
            error "Interactive builder failed"
            raise CommandError
          end

          output ""
          output "Next steps:"
          output "  1. Review the generated configuration file"
          output "  2. Build the package:"
          output "     lutaml-xsd package build #{options[:output] || 'repository.yml'} output.lxr"
        rescue Interrupt
          output ""
          output ""
          output "Interrupted by user"
          output "Session saved. Resume with:"
          output "  lutaml-xsd package init --resume"
          exit 130
        rescue StandardError => e
          error "Init command failed: #{e.message}"
          verbose_output e.backtrace.join("\n") if verbose?
          raise CommandError
        end
      end
    end
  end
end
