# frozen_string_literal: true

require_relative "resource_registry"

module Lutaml
  module Cli
    # ElementIdentifier parses and manages element references
    #
    # Provides a unified syntax for referring to UML elements:
    # - "package:ModelRoot::Core"
    # - "class:ModelRoot::Core::Building"
    # - "diagram:ClassDiagram1"
    # - "attribute:ModelRoot::Core::Building::name"
    #
    # Supports auto-detection when type prefix is omitted.
    #
    # @example Parse an identifier with explicit type
    #   id = ElementIdentifier.parse("class:Building")
    #   id.type # => :class
    #   id.path # => "Building"
    #
    # @example Parse an identifier with auto-detection
    #   id = ElementIdentifier.parse("ModelRoot::Core::Building")
    #   id.type # => :class (auto-detected from pattern)
    #   id.path # => "ModelRoot::Core::Building"
    class ElementIdentifier
      attr_reader :type, :path

      # Parse an element identifier string
      #
      # @param identifier [String] Element identifier in format "type:path"
      # or just "path"
      # @return [ElementIdentifier] Parsed identifier
      # @raise [ArgumentError] If identifier is invalid or type is not
      # registered
      def self.parse(identifier) # rubocop:disable Metrics/MethodLength
        if identifier.nil? || identifier.empty?
          raise ArgumentError,
                "Identifier cannot be nil or empty"
        end

        if identifier.include?(":")
          type, path = identifier.split(":", 2)
          type_sym = type.to_sym

          unless ResourceRegistry.type_registered?(type_sym)
            raise ArgumentError, "Unknown element type: #{type}. " \
                                 "Valid types: " \
                                 "#{ResourceRegistry.types.join(', ')}"
          end

          new(type_sym, path)
        else
          # Auto-detect type from pattern
          detected_type = detect_type(identifier)
          new(detected_type, identifier)
        end
      end

      # Initialize an identifier
      #
      # @param type [Symbol] Element type
      # @param path [String] Element path/name
      def initialize(type, path)
        @type = type
        @path = path
      end

      # Get a human-readable string representation
      #
      # @return [String] String representation
      def to_s
        "#{type}:#{path}"
      end

      # Check if this identifier has an explicit type prefix
      #
      # @param identifier [String] Identifier string
      # @return [Boolean] True if has explicit type prefix
      def self.has_type_prefix?(identifier)
        identifier.include?(":") &&
          ResourceRegistry.type_registered?(identifier.split(":",
                                                             2).first.to_sym)
      end

      # Detect element type from identifier pattern
      #
      # Uses heuristics to determine type:
      # - Multiple :: separators → likely a class
      # - Starts with uppercase → likely a class or package
      # - Contains "Diagram" → likely a diagram
      # - Otherwise → package (safest default)
      #
      # @param identifier [String] Identifier without type prefix
      # @return [Symbol] Detected type
      def self.detect_type(identifier) # rubocop:disable Metrics/MethodLength
        # Check for diagram patterns
        return :diagram if identifier.match?(/diagram/i)

        # Count package separators
        separator_count = identifier.scan("::").size

        case separator_count
        when 0
          # No separators - single name
          # Could be package, class, or diagram
          if identifier.match?(/^[A-Z]/)
            # Starts with uppercase - likely a class or package name
            # Default to package as it's more general
            :package
          else
            # Lowercase start - could be attribute or diagram name
            :diagram
          end
        when 1
          # One separator - likely Package::Class
          :class
        when 2..Float::INFINITY
          # Multiple separators - likely fully qualified class name
          # e.g., ModelRoot::Package::Class
          :class
        else
          # Default
          :package
        end
      end

      # Check if identifier is a qualified name (contains ::)
      #
      # @return [Boolean] True if qualified
      def qualified?
        @path.include?("::")
      end

      # Get the simple name (last component after ::)
      #
      # @return [String] Simple name
      def simple_name
        qualified? ? @path.split("::").last : @path
      end

      # Get the parent path (everything before last ::)
      #
      # @return [String, nil] Parent path or nil if not qualified
      def parent_path
        return nil unless qualified?

        parts = @path.split("::")
        parts[0...-1].join("::")
      end

      # Convert to hash representation
      #
      # @return [Hash] Hash with type and path keys
      def to_h
        {
          type: @type,
          path: @path,
          simple_name: simple_name,
          qualified: qualified?,
        }
      end
    end
  end
end
