# frozen_string_literal: true

require_relative "facet_validator"

module Lutaml
  module Xsd
    module Validation
      module Facets
        # Validates values against XSD minLength facet
        #
        # The minLength facet specifies the minimum length of a value.
        # For strings, it's the minimum number of characters. For lists,
        # it's the minimum number of items.
        #
        # @example Validating minimum length
        #   facet = Lutaml::Xsd::MinLength.new(value: "3")
        #   validator = MinLengthFacetValidator.new(facet)
        #   validator.valid?("hello")  # => true (5 >= 3)
        #   validator.valid?("hi")     # => false (2 < 3)
        #   validator.error_message("hi")
        #   # => "Value length 2 is less than minimum length 3"
        #
        class MinLengthFacetValidator < FacetValidator
          # Validate value meets minimum length
          #
          # @param value [String] The value to validate
          # @return [Boolean] true if value length >= minimum, false otherwise
          def valid?(value)
            return false if value.nil?

            min_length = to_integer(facet_value)
            return false unless min_length

            to_string(value).length >= min_length
          end

          # Generate error message for minimum length violation
          #
          # @param value [String] The invalid value
          # @return [String] Error message describing the violation
          def error_message(value)
            actual_length = value.nil? ? 0 : to_string(value).length
            "Value length #{actual_length} is less than minimum " \
              "length #{facet_value}"
          end
        end
      end
    end
  end
end
