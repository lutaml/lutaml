# frozen_string_literal: true

require_relative "facet_validator"

module Lutaml
  module Xsd
    module Validation
      module Facets
        # Validates values against XSD enumeration facet
        #
        # The enumeration facet restricts a value to a specific set of
        # allowed values.
        #
        # @example Validating enumeration
        #   facet = Lutaml::Xsd::Enumeration.new(value: "red")
        #   validator = EnumerationFacetValidator.new(facet)
        #   validator.valid?("red")   # => true
        #   validator.valid?("blue")  # => false
        #   validator.error_message("blue")
        #   # => "Value 'blue' is not in enumeration ['red']"
        #
        class EnumerationFacetValidator < FacetValidator
          # Validate value is in the enumeration
          #
          # @param value [String] The value to validate
          # @return [Boolean] true if value is in enumeration, false
          #   otherwise
          def valid?(value)
            return false if value.nil?

            allowed_values.include?(to_string(value))
          end

          # Generate error message for enumeration violation
          #
          # @param value [String] The invalid value
          # @return [String] Error message describing the violation
          def error_message(value)
            "Value '#{value}' is not in enumeration #{allowed_values.inspect}"
          end

          private

          # Get all allowed enumeration values
          #
          # @return [Array<String>] Array of allowed values
          def allowed_values
            @allowed_values ||= Array(facet_value).map(&:to_s)
          end
        end
      end
    end
  end
end
