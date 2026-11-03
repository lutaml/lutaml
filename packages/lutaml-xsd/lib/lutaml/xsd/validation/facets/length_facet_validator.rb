# frozen_string_literal: true

require_relative "facet_validator"

module Lutaml
  module Xsd
    module Validation
      module Facets
        # Validates values against XSD length facet
        #
        # The length facet specifies the exact length of a value.
        # For strings, it's the number of characters. For lists,
        # it's the number of items.
        #
        # @example Validating exact length
        #   facet = Lutaml::Xsd::Length.new(value: "5")
        #   validator = LengthFacetValidator.new(facet)
        #   validator.valid?("hello")  # => true (5 chars)
        #   validator.valid?("hi")     # => false (2 chars)
        #   validator.error_message("hi")
        #   # => "Value length 2 does not equal required length 5"
        #
        class LengthFacetValidator < FacetValidator
          # Validate value has exact length
          #
          # @param value [String] The value to validate
          # @return [Boolean] true if value length matches, false otherwise
          def valid?(value)
            return false if value.nil?

            required_length = to_integer(facet_value)
            return false unless required_length

            to_string(value).length == required_length
          end

          # Generate error message for length mismatch
          #
          # @param value [String] The invalid value
          # @return [String] Error message describing the length violation
          def error_message(value)
            actual_length = value.nil? ? 0 : to_string(value).length
            "Value length #{actual_length} does not equal required " \
              "length #{facet_value}"
          end
        end
      end
    end
  end
end
