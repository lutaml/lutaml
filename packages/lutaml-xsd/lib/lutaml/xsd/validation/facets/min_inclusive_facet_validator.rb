# frozen_string_literal: true

require_relative "facet_validator"

module Lutaml
  module Xsd
    module Validation
      module Facets
        # Validates values against XSD minInclusive facet
        #
        # The minInclusive facet specifies the minimum value (inclusive)
        # for numeric types.
        #
        # @example Validating minimum inclusive
        #   facet = Lutaml::Xsd::MinInclusive.new(value: "10")
        #   validator = MinInclusiveFacetValidator.new(facet)
        #   validator.valid?("10")  # => true (10 >= 10)
        #   validator.valid?("15")  # => true (15 >= 10)
        #   validator.valid?("5")   # => false (5 < 10)
        #   validator.error_message("5")
        #   # => "Value 5 is less than minimum inclusive value 10"
        #
        class MinInclusiveFacetValidator < FacetValidator
          # Validate value is >= minimum
          #
          # @param value [String, Numeric] The value to validate
          # @return [Boolean] true if value >= minimum, false otherwise
          def valid?(value)
            return false if value.nil?

            numeric_value = to_numeric(value)
            min_value = to_numeric(facet_value)

            return false unless numeric_value && min_value

            numeric_value >= min_value
          end

          # Generate error message for minimum inclusive violation
          #
          # @param value [String, Numeric] The invalid value
          # @return [String] Error message describing the violation
          def error_message(value)
            "Value #{value} is less than minimum inclusive value " \
              "#{facet_value}"
          end
        end
      end
    end
  end
end
