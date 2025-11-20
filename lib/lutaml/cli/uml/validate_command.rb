# frozen_string_literal: true

require_relative "../output_formatter"
module Lutaml
  module Cli
    module Uml
      # ValidateCommand validates LUR packages or QEA files
      class ValidateCommand
        attr_reader :options

        def initialize(options = {})
          @options = options.transform_keys(&:to_sym)
        end

        def self.add_options_to(thor_class, _method_name)
          thor_class.long_desc <<-DESC
          Validate a LUR package or QEA file for consistency and completeness.

          Auto-detects file type:
          - .lur files: Validate LUR package structure
          - .qea files: Validate QEA file structure and integrity

          LUR validation checks:
          - Dangling references
          - Missing types
          - External dependencies
          - Structural integrity

          QEA validation checks:
          - Package structure validation
          - Class and attribute validation
          - Association endpoint validation
          - Referential integrity
          - Orphaned elements
          - Circular references

          Examples:
            lutaml uml validate model.lur
            lutaml uml validate model.qea
            lutaml uml validate model.qea --format json -o report.json
          DESC

          thor_class.option :format, type: :string, default: "text",
                                     desc: "Output format (text|json)"
          thor_class.option :output, aliases: "-o", type: :string,
                                     desc: "Save report to file"
          thor_class.option :strict, type: :boolean, default: false,
                                     desc: "Exit with error if validation fails"
          thor_class.option :show_warnings, type: :boolean, default: true,
                                            desc: "Show warnings in output"
          thor_class.option :verbose, type: :boolean, default: false,
                                      desc: "Show detailed validation messages"
        end

        def run(file_path)
          unless File.exist?(file_path)
            puts OutputFormatter.error("File not found: #{file_path}")
            raise Thor::Error, "File not found: #{file_path}"
          end

          # Auto-detect file type
          if file_path.end_with?(".qea")
            validate_qea_file(file_path)
          elsif file_path.end_with?(".lur")
            validate_lur_file(file_path)
          else
            puts OutputFormatter.error(
              "Unsupported file type. Please provide a .qea or .lur file.",
            )
            raise Thor::Error, "Unsupported file type. Please provide a .qea or .lur file."
          end
        rescue StandardError => e
          OutputFormatter.progress_done(success: false)
          puts OutputFormatter.error("Validation failed: #{e.message}")
          puts e.backtrace.first(5).join("\n") if ENV["DEBUG"]
        end

        private

        def validate_lur_file(lur_path)
          OutputFormatter.progress("Loading package")
          repo = Lutaml::UmlRepository::Repository.from_package(lur_path)
          OutputFormatter.progress_done

          OutputFormatter.progress("Validating repository")
          result = repo.validate
          OutputFormatter.progress_done

          puts ""
          if result.valid?
            puts OutputFormatter.success("Package is valid")
          else
            puts OutputFormatter.warning("Package has validation issues")
          end

          display_validation_results(result)

          if options[:strict] && result.errors.any?
            raise Thor::Error, "Package validation failed"
          end
        end

        def validate_qea_file(qea_path)
          require_relative "../../qea"

          puts OutputFormatter.colorize("\n=== QEA File Validation ===\n",
                                        :cyan)
          puts "File: #{qea_path}"
          puts ""

          # Parse with validation
          OutputFormatter.progress("Loading and validating QEA file")
          result = Lutaml::Qea.parse(qea_path, validate: true)
          OutputFormatter.progress_done

          result[:document]
          validation_result = result[:validation_result]

          # Format output
          formatter_class = case options[:format].downcase
                            when "json"
                              Lutaml::Qea::Validation::Formatters::JsonFormatter
                            else
                              Lutaml::Qea::Validation::Formatters::TextFormatter
                            end

          formatter_options = {
            result: validation_result,
            verbose: options[:verbose],
          }
          formatter_options[:color] = true if options[:format] == "text"

          formatter = formatter_class.new(**formatter_options)
          output = formatter.format

          # Display or save output
          if options[:output]
            File.write(options[:output], output)
            puts OutputFormatter.success("Validation report saved to: #{options[:output]}")
          else
            puts output
          end

          # Exit with appropriate status
          if options[:strict] && validation_result.has_errors?
            puts ""
            puts OutputFormatter.error("Validation FAILED")
            raise Thor::Error, "Validation FAILED"
          elsif validation_result.valid?
            puts ""
            puts OutputFormatter.success("Validation PASSED")
          end
        end

        def display_validation_results(result)
          if result.warnings.any?
            puts ""
            puts OutputFormatter.colorize("Warnings:", :yellow)
            result.warnings.each { |w| puts "  - #{w}" }
          end

          if result.errors.any?
            puts ""
            puts OutputFormatter.colorize("Errors:", :red)
            result.errors.each { |e| puts "  - #{e}" }
          end

          if result.has_external_references?
            puts ""
            puts OutputFormatter.colorize(
              "External Type References (#{result.external_references.size}):", :cyan
            )
            puts ""
            puts OutputFormatter.format_array_table(
              result.external_references,
              options: {
                title: "Types referenced but not defined in this repository",
                layout: false,
              },
            )
          end
        end
      end
    end
  end
end
