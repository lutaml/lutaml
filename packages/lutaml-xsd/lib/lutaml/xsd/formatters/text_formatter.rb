# frozen_string_literal: true

require_relative "base"

module Lutaml
  module Xsd
    module Formatters
      # Text formatter for validation results
      # Outputs human-readable text with symbols and colors
      class TextFormatter < Base
        # Format validation results as human-readable text
        #
        # @param results [Hash] Validation results
        # @return [String] Formatted text output
        def format(results)
          # Output each file result
          output = results[:files].map do |file_result|
            format_file_result(file_result)
          end

          # Add summary
          output << ""
          output << "Summary:"
          output << "  Total: #{results[:total]}"
          output << "  Valid: #{results[:valid]}"
          output << "  Invalid: #{results[:invalid]}"

          output.join("\n")
        end

        private

        # Format a single file result
        def format_file_result(file_result)
          if file_result[:valid]
            format_valid_file(file_result)
          else
            format_invalid_file(file_result)
          end
        end

        # Format a valid file result
        def format_valid_file(file_result)
          if file_result[:detected_version]
            "✓ #{file_result[:file]} (XSD #{file_result[:detected_version]})"
          else
            "✓ #{file_result[:file]}"
          end
        end

        # Format an invalid file result
        def format_invalid_file(file_result)
          output = []
          output << "✗ #{file_result[:file]}"
          output << "  Error: #{file_result[:error]}"
          output.join("\n")
        end
      end
    end
  end
end
