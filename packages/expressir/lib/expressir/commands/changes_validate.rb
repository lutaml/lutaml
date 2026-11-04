# frozen_string_literal: true

module Expressir
  module Commands
    # Command to validate and normalize EXPRESS Changes YAML files
    class ChangesValidate < Base
      def run(path)
        # Check if file exists
        unless File.exist?(path)
          exit_with_error("File not found: #{path}")
        end

        # Validate --in-place requires --normalize
        if options[:in_place] && !options[:normalize]
          exit_with_error("--in-place requires --normalize flag")
        end

        # Validate --in-place and --output are mutually exclusive
        if options[:in_place] && options[:output]
          exit_with_error("Cannot use both --in-place and --output")
        end

        begin
          # Load and validate the file
          say "Validating #{path}..." if options[:verbose]
          schema_change = Expressir::Changes::SchemaChange.from_file(path)

          say "✓ File is valid" if options[:verbose]
          say "  Schema: #{schema_change.schema}" if options[:verbose]
          say "  Versions: #{schema_change.versions.length}" if options[:verbose]

          # Normalize if requested
          if options[:normalize]
            say "Normalizing through round-trip serialization..." if options[:verbose]

            output_path = if options[:in_place]
                            path
                          elsif options[:output]
                            options[:output]
                          else
                            # Output to stdout
                            nil
                          end

            if output_path
              schema_change.to_file(output_path)
              say "✓ Normalized file written to: #{output_path}"
            else
              # Output to stdout
              puts schema_change.to_yaml
            end
          else
            say "✓ File is valid"
          end
        rescue Psych::SyntaxError => e
          exit_with_error("Invalid YAML syntax: #{e.message}")
        rescue StandardError => e
          exit_with_error("Validation failed: #{e.message}")
        end
      end
    end
  end
end
