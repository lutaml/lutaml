# frozen_string_literal: true

require_relative "text_formatter"
require_relative "json_formatter"
require_relative "yaml_formatter"
require_relative "registry"

module Lutaml
  module Xsd
    module Formatters
      # Factory for creating formatter instances
      # Provides a centralized way to create formatters based on format
      # strings. Uses Registry internally for dynamic formatter registration.
      class FormatterFactory
        # Initialize the internal registry with built-in formatters
        @registry = Registry.new
        @registry.register("text", TextFormatter)
        @registry.register("json", JsonFormatter)
        @registry.register("yaml", YamlFormatter)

        class << self
          # Create a formatter instance for the specified format
          #
          # @param format [String] The format name (text, json, or yaml)
          # @return [Base] A formatter instance
          # @raise [ArgumentError] If the format is unknown
          def create(format)
            @registry.create(format)
          end

          # Get list of supported format names
          #
          # @return [Array<String>] Array of supported format names
          def supported_formats
            @registry.supported_formats
          end

          # Check if a format is supported
          #
          # @param format [String] The format name to check
          # @return [Boolean] True if the format is supported
          def supported?(format)
            @registry.supported?(format)
          end

          # Register a new formatter class
          # This allows runtime registration of custom formatters
          #
          # @param name [String, Symbol] The format name
          # @param formatter_class [Class] The formatter class
          # @return [void]
          # @raise [ArgumentError] If formatter_class doesn't inherit from Base
          def register(name, formatter_class)
            @registry.register(name, formatter_class)
          end

          # Access the internal registry (for testing or advanced usage)
          #
          # @return [Registry] The internal registry instance
          # @api private
          def registry
            @registry
          end
        end
      end
    end
  end
end
