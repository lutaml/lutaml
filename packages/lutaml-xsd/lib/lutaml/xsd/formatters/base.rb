# frozen_string_literal: true

module Lutaml
  module Xsd
    module Formatters
      # Base class for all output formatters
      # Defines the interface that all formatters must implement
      class Base
        # Format validation results into the desired output format
        #
        # @param results [Hash] Validation results hash containing:
        #   - total: Total number of files validated
        #   - valid: Number of valid files
        #   - invalid: Number of invalid files
        #   - files: Array of file results
        #   - failed_files: Array of failed file paths
        # @return [String] Formatted output string
        def format(results)
          raise NotImplementedError,
                "#{self.class} must implement #format method"
        end
      end
    end
  end
end
