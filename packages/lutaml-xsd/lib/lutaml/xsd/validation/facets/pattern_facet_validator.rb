# frozen_string_literal: true

require_relative "facet_validator"

module Lutaml
  module Xsd
    module Validation
      module Facets
        # Validates values against XSD pattern facet (regex)
        #
        # The pattern facet validates that a value matches a regular
        # expression pattern defined in the schema.
        #
        # @example Validating against a pattern
        #   facet = Lutaml::Xsd::Pattern.new(value: "[A-Z]{2}[0-9]{4}")
        #   validator = PatternFacetValidator.new(facet)
        #   validator.valid?("AB1234")  # => true
        #   validator.valid?("ab1234")  # => false
        #   validator.error_message("ab1234")
        #   # => "Value 'ab1234' does not match pattern '[A-Z]{2}[0-9]{4}'"
        #
        class PatternFacetValidator < FacetValidator
          # Validate value matches the regex pattern
          #
          # @param value [String] The value to validate
          # @return [Boolean] true if value matches pattern, false otherwise
          def valid?(value)
            return false if value.nil?

            pattern = compile_pattern
            return false unless pattern

            to_string(value).match?(pattern)
          end

          # Generate error message for pattern mismatch
          #
          # @param value [String] The invalid value
          # @return [String] Error message describing the pattern violation
          def error_message(value)
            "Value '#{value}' does not match pattern '#{facet_value}'"
          end

          private

          # Compile the regex pattern from facet value
          #
          # @return [Regexp, nil] Compiled regex or nil if invalid
          def compile_pattern
            return @compiled_pattern if defined?(@compiled_pattern)

            @compiled_pattern = Regexp.new(facet_value)
          rescue RegexpError => e
            warn "Invalid regex pattern '#{facet_value}': #{e.message}"
            @compiled_pattern = nil
          end
        end
      end
    end
  end
end
