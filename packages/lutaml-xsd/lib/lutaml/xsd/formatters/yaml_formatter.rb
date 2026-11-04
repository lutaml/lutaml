# frozen_string_literal: true

require "yaml"
require_relative "base"

module Lutaml
  module Xsd
    module Formatters
      # YAML formatter for validation results
      # Outputs machine-readable YAML format for CI/CD integration
      class YamlFormatter < Base
        # Format validation results as YAML
        #
        # @param results [Hash] Validation results
        # @return [String] Formatted YAML output
        def format(results)
          output = {
            "summary" => {
              "total" => results[:total],
              "valid" => results[:valid],
              "invalid" => results[:invalid],
            },
            "results" => format_file_results(results[:files]),
          }

          YAML.dump(output)
        end

        private

        # Format file results for YAML output
        def format_file_results(files)
          files.map do |file_result|
            {
              "file" => file_result[:file],
              "valid" => file_result[:valid],
              "error" => file_result[:error],
              "detected_version" => file_result[:detected_version],
            }.compact
          end
        end
      end
    end
  end
end
