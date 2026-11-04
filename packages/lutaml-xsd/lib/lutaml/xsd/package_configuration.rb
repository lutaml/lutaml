# frozen_string_literal: true

module Lutaml
  module Xsd
    # Configuration for schema repository package creation
    # Defines three independent options:
    # 1. XSD Mode: How XSD files are included
    # 2. Resolution Mode: Whether to pre-serialize parsed schemas
    # 3. Serialization Format: How schemas are serialized/deserialized
    class PackageConfiguration
      # XSD inclusion modes
      XSD_MODES = {
        include_all: :include_all, # Bundle all XSDs with rewritten paths
        allow_external: :allow_external, # Keep external references
      }.freeze

      # Resolution modes
      RESOLUTION_MODES = {
        bare: :bare, # Parse on load (smaller metadata)
        resolved: :resolved, # Instant load (serialized schemas included)
      }.freeze

      # Serialization formats
      SERIALIZATION_FORMATS = {
        marshal: :marshal,  # Ruby Marshal (fastest, binary)
        json: :json,        # JSON format (portable, human-readable)
        yaml: :yaml,        # YAML format (portable, human-readable)
        parse: :parse, # Parse XSD files (no serialization)
      }.freeze

      attr_reader :xsd_mode, :resolution_mode, :serialization_format

      # @param xsd_mode [Symbol] :include_all or :allow_external
      # @param resolution_mode [Symbol] :bare or :resolved
      # @param serialization_format [Symbol] :marshal, :json, :yaml, or :parse
      def initialize(xsd_mode: :include_all, resolution_mode: :resolved,
serialization_format: :marshal)
        @xsd_mode = validate_mode(xsd_mode, XSD_MODES, "XSD mode")
        @resolution_mode = validate_mode(resolution_mode, RESOLUTION_MODES,
                                         "Resolution mode")
        @serialization_format = validate_mode(serialization_format,
                                              SERIALIZATION_FORMATS, "Serialization format")
      end

      # @return [Boolean] Whether to include all XSD files in package
      def include_all_xsds?
        @xsd_mode == :include_all
      end

      # @return [Boolean] Whether to allow external XSD references
      def allow_external_xsds?
        @xsd_mode == :allow_external
      end

      # @return [Boolean] Whether package includes pre-resolved schemas
      def resolved_package?
        @resolution_mode == :resolved
      end

      # @return [Boolean] Whether package requires parsing on load
      def bare_package?
        @resolution_mode == :bare
      end

      # @return [Boolean] Whether to use marshal serialization
      def marshal_format?
        @serialization_format == :marshal
      end

      # @return [Boolean] Whether to use JSON serialization
      def json_format?
        @serialization_format == :json
      end

      # @return [Boolean] Whether to use YAML serialization
      def yaml_format?
        @serialization_format == :yaml
      end

      # @return [Boolean] Whether to parse XSD files (no serialization)
      def parse_format?
        @serialization_format == :parse
      end

      # @return [Hash] Configuration as hash
      def to_h
        {
          xsd_mode: @xsd_mode,
          resolution_mode: @resolution_mode,
          serialization_format: @serialization_format,
        }
      end

      # Create from hash
      # @param data [Hash] Configuration data
      # @return [PackageConfiguration]
      def self.from_hash(data)
        new(
          xsd_mode: data[:xsd_mode] || data["xsd_mode"],
          resolution_mode: data[:resolution_mode] || data["resolution_mode"],
          serialization_format: data[:serialization_format] || data["serialization_format"] || :marshal,
        )
      end

      private

      # Validate mode value
      # @param mode [Symbol] Mode value to validate
      # @param valid_modes [Hash] Hash of valid modes
      # @param mode_name [String] Name of mode for error message
      # @return [Symbol] Validated mode
      def validate_mode(mode, valid_modes, mode_name)
        mode_sym = mode.to_sym
        unless valid_modes.key?(mode_sym)
          raise ArgumentError,
                "Invalid #{mode_name}: #{mode}. " \
                "Valid options: #{valid_modes.keys.join(', ')}"
        end
        mode_sym
      end
    end
  end
end
