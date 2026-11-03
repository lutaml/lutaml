# frozen_string_literal: true

require_relative "facet_validator"

module Lutaml
  module Xsd
    module Validation
      module Facets
        # Validates and normalizes values against XSD whiteSpace facet
        #
        # The whiteSpace facet specifies how whitespace should be handled:
        # - preserve: All whitespace is preserved
        # - replace: Each tab, newline, and carriage return is replaced with
        #   a space
        # - collapse: Sequences of whitespace are collapsed to a single
        #   space, and leading/trailing whitespace is removed
        #
        # @example Validating whitespace handling
        #   facet = Lutaml::Xsd::WhiteSpace.new(value: "collapse")
        #   validator = WhiteSpaceFacetValidator.new(facet)
        #   validator.valid?("  hello  world  ")  # => true
        #   validator.normalize("  hello  world  ")  # => "hello world"
        #
        class WhiteSpaceFacetValidator < FacetValidator
          PRESERVE = "preserve"
          REPLACE = "replace"
          COLLAPSE = "collapse"

          # Validate always returns true as whiteSpace is about
          # normalization
          #
          # @param value [String] The value to validate
          # @return [Boolean] Always true
          def valid?(_value)
            true
          end

          # Generate error message (not typically used for whiteSpace)
          #
          # @param value [String] The value
          # @return [String] Error message
          def error_message(value)
            "Invalid whitespace handling for value: #{value}"
          end

          # Normalize value according to whiteSpace facet
          #
          # @param value [String] The value to normalize
          # @return [String] Normalized value
          def normalize(value)
            return value if value.nil?

            case facet_value
            when PRESERVE
              value
            when REPLACE
              replace_whitespace(value)
            when COLLAPSE
              collapse_whitespace(value)
            else
              value
            end
          end

          private

          # Replace tabs, newlines, and carriage returns with spaces
          #
          # @param value [String] The value to process
          # @return [String] Value with replaced whitespace
          def replace_whitespace(value)
            value.gsub(/[\t\n\r]/, " ")
          end

          # Collapse sequences of whitespace and trim
          #
          # @param value [String] The value to process
          # @return [String] Value with collapsed whitespace
          def collapse_whitespace(value)
            # First replace tabs, newlines, carriage returns with spaces
            result = replace_whitespace(value)
            # Then collapse multiple spaces to single space
            result = result.gsub(/\s+/, " ")
            # Finally trim leading and trailing whitespace
            result.strip
          end
        end
      end
    end
  end
end
