# frozen_string_literal: true

require_relative "base_command"
require_relative "../spa/generator"

module Lutaml
  module Xsd
    module Commands
      # CLI command for generating SPA documentation
      #
      # Generates interactive HTML Single Page Application documentation
      # from XSD schemas with Vue.js frontend.
      class GenerateSpaCommand < BaseCommand
        attr_reader :package_path, :output_path

        # Initialize spa command
        #
        # @param package_path [String] Path to LXR package file
        # @param options [Hash] Command options
        def initialize(package_path, options = {})
          super(options)
          @package_path = package_path
          @output_path = options[:output]
        end

        # Run SPA generation command
        #
        # @return [void]
        def run
          validate_inputs
          package = load_package
          generator = create_generator(package)

          output_files = generator.generate
          display_results(output_files)
        rescue StandardError => e
          error "SPA generation failed: #{e.message}"
          verbose_output e.backtrace.join("\n") if verbose?
          raise CommandError
        end

        private

        # Validate command inputs
        #
        # @return [void]
        def validate_inputs
          unless package_path
            error "No package file specified"
            error "Usage: lutaml-xsd spa PACKAGE --output FILE [options]"
            raise CommandError
          end

          unless File.exist?(package_path)
            error "Package file not found: #{package_path}"
            raise CommandError
          end

          unless output_path
            error "No output file specified. Use --output option"
            raise CommandError
          end
        end

        # Load package
        #
        # @return [SchemaRepositoryPackage] Package instance
        def load_package
          verbose_output "Loading package: #{package_path}"

          package_obj = SchemaRepositoryPackage.load(package_path)

          verbose_output "✓ Package loaded successfully"
          package_obj
        end

        # Create SPA generator instance
        #
        # @param package [SchemaRepositoryPackage] Schema package
        # @return [Spa::Generator] Generator instance
        def create_generator(package)
          verbose_output "Initializing SPA generator..."

          mode = options[:mode] || "inlined"

          generator = Spa::Generator.new(
            package,
            output_path,
            mode: mode,
            verbose: verbose?,
          )

          verbose_output "✓ Generator initialized in #{mode} mode"
          generator
        end

        # Display generation results
        #
        # @param output_files [Array<String>] List of generated files
        # @return [void]
        def display_results(output_files)
          output ""
          output "SPA Documentation Generated Successfully"
          output "=" * 80
          output ""

          if output_files.size == 1
            output "Output file:"
            output "  #{output_files.first}"
          else
            output "Output files (#{output_files.size} total):"
            output_files.each do |file|
              output "  #{file}"
            end
          end

          output ""
          output "✓ Generation complete"
        end
      end
    end
  end
end
