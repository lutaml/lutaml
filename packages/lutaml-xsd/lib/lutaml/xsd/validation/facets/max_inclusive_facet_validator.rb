# frozen_string_literal: true

require_relative "facet_validator"

module Lutaml
  module Xsd
    module Validation
      module Facets
        # Validates values against XSD maxInclusive facet
        #
        # The maxInclusive facet specifies the maximum value (inclusive)
        # for numeric types.
        #
        # @example Validating maximum inclusive
        #   facet = Lutaml::Xsd::MaxInclusive.new(value: "100")
        #   validator = MaxInclusiveFacetValidator.new(facet)
        #   validator.valid?("100")  # => true (100 <= 100)
        #   validator.valid?("50")   # => true (50 <= 100)
        #   validator.valid?("150")  # => false (150 > 100)
        #   validator.error_message("150")
        #   # => "Value 150 exceeds maximum inclusive value 100"
        #
        class MaxInclusiveFacetValidator < FacetValidator
          # Validate value is <= maximum
          #
          # @param value [String, Numeric] The value to validate
          # @return [Boolean] true if value <= maximum, false otherwise
          def valid?(value)
            return false if value.nil?

            numeric_value = to_numeric(value)
            max_value = to_numeric(facet_value)

            return false unless numeric_value && max_value

            numeric_value <= max_value
          end

          # Generate error message for maximum inclusive violation
          #
          # @param value [String, Numeric] The invalid value
          # @return [String] Error message describing the violation
          def error_message(value)
            "Value #{value} exceeds maximum inclusive value #{facet_value}"
          end
        end
      end
    end
  end
end
