# frozen_string_literal: true

require_relative "base_type_validator"

module Lutaml
  module Xsd
    module Validation
      module BaseTypes
        # Validates XSD anyURI type
        #
        # The anyURI type represents a Uniform Resource Identifier (URI)
        # reference. This includes URLs, URNs, and relative URIs.
        #
        # @example Validating URI values
        #   validator = AnyURIValidator.new
        #   validator.valid?("https://example.com")           # => true
        #   validator.valid?("http://example.com/path")       # => true
        #   validator.valid?("ftp://ftp.example.com")         # => true
        #   validator.valid?("mailto:user@example.com")       # => true
        #   validator.valid?("urn:isbn:0-486-27557-4")        # => true
        #   validator.valid?("../relative/path")              # => true
        #   validator.valid?("not a uri with spaces")         # => false
        #
        class AnyURIValidator < BaseTypeValidator
          # Validate value is a valid URI
          #
          # @param value [Object] The value to validate
          # @return [Boolean] true if value is a valid URI
          def valid?(value)
            return false if value.nil?
            return true if value.is_a?(URI)

            str = to_string(value).strip
            return false if str.empty?

            # Try to parse as URI
            URI.parse(str)
            true
          rescue URI::InvalidURIError
            false
          end

          # Generate error message for invalid URI
          #
          # @param value [Object] The invalid value
          # @return [String] Error message
          def error_message(value)
            "Value '#{value}' is not a valid URI"
          end
        end
      end
    end
  end
end
