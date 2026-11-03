# frozen_string_literal: true

require_relative "facet_validator"

module Lutaml
  module Xsd
    module Validation
      module Facets
        # Validates values against XSD maxLength facet
        #
        # The maxLength facet specifies the maximum length of a value.
        # For strings, it's the maximum number of characters. For lists,
        # it's the maximum number of items.
        #
        # @example Validating maximum length
        #   facet = Lutaml::Xsd::MaxLength.new(value: "5")
        #   validator = MaxLengthFacetValidator.new(facet)
        #   validator.valid?("hi")     # => true (2 <= 5)
        #   validator.valid?("hello!")  # => false (6 > 5)
        #   validator.error_message("hello!")
        #   # => "Value length 6 exceeds maximum length 5"
        #
        class MaxLengthFacetValidator < FacetValidator
          # Validate value meets maximum length
          #
          # @param value [String] The value to validate
          # @return [Boolean] true if value length <= maximum, false otherwise
          def valid?(value)
            return false if value.nil?

            max_length = to_integer(facet_value)
            return false unless max_length

            to_string(value).length <= max_length
          end

          # Generate error message for maximum length violation
          #
          # @param value [String] The invalid value
          # @return [String] Error message describing the violation
          def error_message(value)
            actual_length = value.nil? ? 0 : to_string(value).length
            "Value length #{actual_length} exceeds maximum " \
              "length #{facet_value}"
          end
        end
      end
    end
  end
end
