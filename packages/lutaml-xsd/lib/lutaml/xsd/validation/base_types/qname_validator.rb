# frozen_string_literal: true

require_relative "base_type_validator"

module Lutaml
  module Xsd
    module Validation
      module BaseTypes
        # Validates XSD QName type
        #
        # The QName (Qualified Name) type represents an XML qualified name,
        # which consists of an optional namespace prefix and a local part
        # separated by a colon.
        #
        # @example Validating QName values
        #   validator = QNameValidator.new
        #   validator.valid?("prefix:localName")  # => true
        #   validator.valid?("localName")         # => true
        #   validator.valid?("ns:element")        # => true
        #   validator.valid?(":noPrefix")         # => false
        #   validator.valid?("prefix:")           # => false
        #   validator.valid?("has space")         # => false
        #
        class QNameValidator < BaseTypeValidator
          # NCName pattern (Non-Colonized Name)
          NCNAME_PATTERN = /^[a-zA-Z_][\w.-]*$/

          # QName pattern (prefix:localName or just localName)
          QNAME_PATTERN = /^([a-zA-Z_][\w.-]*:)?[a-zA-Z_][\w.-]*$/

          # Validate value is a valid QName
          #
          # @param value [Object] The value to validate
          # @return [Boolean] true if value is a valid QName
          def valid?(value)
            return false if value.nil?

            str = to_string(value).strip
            return false if str.empty?

            # Must match QName pattern
            return false unless str.match?(QNAME_PATTERN)

            # If it has a colon, validate both parts
            if str.include?(":")
              prefix, local = str.split(":", 2)
              return false if prefix.empty? || local.empty?
              return false unless prefix.match?(NCNAME_PATTERN)
              return false unless local.match?(NCNAME_PATTERN)
            end

            true
          end

          # Generate error message for invalid QName
          #
          # @param value [Object] The invalid value
          # @return [String] Error message
          def error_message(value)
            "Value '#{value}' is not a valid QName. " \
              "Expected format: [prefix:]localName"
          end
        end
      end
    end
  end
end
