# frozen_string_literal: true

require_relative "facet_validator"

module Lutaml
  module Xsd
    module Validation
      module Facets
        # Validates values against XSD maxExclusive facet
        #
        # The maxExclusive facet specifies the maximum value (exclusive)
        # for numeric types.
        #
        # @example Validating maximum exclusive
        #   facet = Lutaml::Xsd::MaxExclusive.new(value: "100")
        #   validator = MaxExclusiveFacetValidator.new(facet)
        #   validator.valid?("100")  # => false (100 == 100)
        #   validator.valid?("99")   # => true (99 < 100)
        #   validator.valid?("150")  # => false (150 > 100)
        #   validator.error_message("150")
        #   # => "Value 150 is not less than maximum exclusive value 100"
        #
        class MaxExclusiveFacetValidator < FacetValidator
          # Validate value is < maximum
          #
          # @param value [String, Numeric] The value to validate
          # @return [Boolean] true if value < maximum, false otherwise
          def valid?(value)
            return false if value.nil?

            numeric_value = to_numeric(value)
            max_value = to_numeric(facet_value)

            return false unless numeric_value && max_value

            numeric_value < max_value
          end

          # Generate error message for maximum exclusive violation
          #
          # @param value [String, Numeric] The invalid value
          # @return [String] Error message describing the violation
          def error_message(value)
            "Value #{value} is not less than maximum exclusive value " \
              "#{facet_value}"
          end
        end
      end
    end
  end
end
