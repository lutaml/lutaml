# frozen_string_literal: true

require "json"
require_relative "base"

module Lutaml
  module Xsd
    module Formatters
      # JSON formatter for validation results
      # Outputs machine-readable JSON format for CI/CD integration
      class JsonFormatter < Base
        # Format validation results as JSON
        #
        # @param results [Hash] Validation results
        # @return [String] Formatted JSON output
        def format(results)
          output = {
            summary: {
              total: results[:total],
              valid: results[:valid],
              invalid: results[:invalid],
            },
            results: format_file_results(results[:files]),
          }

          JSON.pretty_generate(output)
        end

        private

        # Format file results for JSON output
        def format_file_results(files)
          files.map do |file_result|
            {
              file: file_result[:file],
              valid: file_result[:valid],
              error: file_result[:error],
              detected_version: file_result[:detected_version],
            }.compact
          end
        end
      end
    end
  end
end
