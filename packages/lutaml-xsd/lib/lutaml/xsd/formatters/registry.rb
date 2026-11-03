# frozen_string_literal: true

require_relative "base"

module Lutaml
  module Xsd
    module Formatters
      # Registry for dynamically managing formatter classes
      # Enables plugin-style formatter registration
      class Registry
        def initialize
          @formatters = {}
        end

        # Register a formatter class
        # @param name [String, Symbol] Format name (e.g., 'json', 'yaml')
        # @param formatter_class [Class] Formatter class (must inherit from Base)
        # @raise [ArgumentError] if formatter_class doesn't inherit from Base
        def register(name, formatter_class)
          unless formatter_class < Base
            raise ArgumentError,
                  "Formatter must inherit from Lutaml::Xsd::Formatters::Base"
          end

          @formatters[name.to_s] = formatter_class
        end

        # Create a formatter instance by name
        # @param name [String, Symbol] Format name
        # @return [Base] Formatter instance
        # @raise [ArgumentError] if format is not registered
        def create(name)
          formatter_class = @formatters[name.to_s]
          unless formatter_class
            raise ArgumentError,
                  "Unknown format: #{name}. " \
                  "Supported formats: #{supported_formats.join(', ')}"
          end

          formatter_class.new
        end

        # Get list of supported format names
        # @return [Array<String>] Registered format names
        def supported_formats
          @formatters.keys.sort
        end

        # Check if a format is supported
        # @param name [String, Symbol] Format name
        # @return [Boolean] true if format is registered
        def supported?(name)
          @formatters.key?(name.to_s)
        end

        # Unregister a formatter
        # @param name [String, Symbol] Format name
        # @return [Class, nil] Removed formatter class or nil if not found
        def unregister(name)
          @formatters.delete(name.to_s)
        end

        # Clear all registered formatters
        def clear
          @formatters.clear
        end

        # Get count of registered formatters
        # @return [Integer] Number of registered formatters
        def count
          @formatters.size
        end
      end
    end
  end
end
