# frozen_string_literal: true

require_relative "base_command"

module Lutaml
  module Xsd
    module Commands
      # Command for verifying XSD specification compliance
      # Validates schemas against W3C XSD specification requirements
      class VerifyCommand < BaseCommand
        def initialize(package_path, options)
          super(options)
          @package_path = package_path
          @xsd_version = options[:xsd_version] || "1.0"
          @strict = options[:strict] || false
          @format = options[:format] || "text"
        end

        def run
          validate_package_exists
          perform_spec_verification
        end

        private

        def validate_package_exists
          return if File.exist?(@package_path)

          error "Package file not found: #{@package_path}"
          raise CommandError
        end

        def perform_spec_verification
          verbose_output "Loading package: #{@package_path}"
          repository = load_repository(@package_path)
          ensure_resolved(repository)

          verbose_output "Validating XSD #{@xsd_version} specification compliance..."

          # Perform spec validation
          report = repository.validate_xsd_spec(version: @xsd_version)

          # Display results
          display_results(report)

          # Exit with appropriate code
          exit_code = determine_exit_code(report)
          exit exit_code if exit_code.positive?
        rescue StandardError => e
          error "Specification verification failed: #{e.message}"
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
          output "=" * 80
          output "XSD Specification Compliance Verification"
          output "=" * 80
          output ""

          # Overall status
          if report.valid
            output "✓ VALID - All schemas comply with XSD #{report.version} specification"
          else
            output "✗ INVALID - Specification violations found"
          end
          output ""

          # Statistics
          output "Statistics:"
          output "  XSD Version: #{report.version}"
          output "  Schemas checked: #{report.schemas_checked}"
          output "  Errors: #{report.errors.size}"
          output "  Warnings: #{report.warnings.size}"
          output ""

          # Errors
          if report.errors.any?
            output "Errors (#{report.errors.size}):"
            output "-" * 80
            report.errors.each_with_index do |err, idx|
              output "#{idx + 1}. #{err}"
            end
            output ""
          end

          # Warnings
          if report.warnings.any?
            output "Warnings (#{report.warnings.size}):"
            output "-" * 80
            report.warnings.each_with_index do |warn, idx|
              output "#{idx + 1}. #{warn}"
            end
            output ""
          end

          # Summary
          output "=" * 80
          if report.valid
            if report.warnings.any?
              output "✓ Schemas are valid but have #{report.warnings.size} warning(s)"
              output "  Consider addressing warnings for better XSD compliance"
            else
              output "✓ All schemas fully comply with XSD #{report.version} specification"
            end
          else
            output "✗ Schemas have specification violations"
            output "  Fix the #{report.errors.size} error(s) above for spec compliance"
          end
          output "=" * 80
        end

        def determine_exit_code(report)
          # Exit with error if not valid
          return 1 unless report.valid

          # Exit with error if strict and has warnings
          return 1 if @strict && report.warnings.any?

          # Success
          0
        end
      end
    end
  end
end
