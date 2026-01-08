# frozen_string_literal: true

require "lutaml/model"
require "yaml"

module Lutaml
  module ModelTransformations
    # Configuration service for model transformations using external YAML configuration.
    #
    # This class follows the Dependency Inversion Principle by allowing external
    # configuration instead of hardcoded behavior. It uses lutaml-model for
    # structured YAML parsing and validation.
    #
    # @example Load default configuration
    #   config = Configuration.load
    #   puts config.enabled_formats
    #
    # @example Load custom configuration
    #   config = Configuration.load("my_config.yml")
    #   parser_config = config.parser_config_for("xmi")
    class Configuration < Lutaml::Model::Serializable
      # Parser configuration model
      class ParserConfig < Lutaml::Model::Serializable
        attribute :format, :string
        attribute :extension, :string
        attribute :parser_class, :string
        attribute :enabled, :boolean, default: -> { true }
        attribute :priority, :integer, default: -> { 100 }
        attribute :description, :string
        attribute :options, :string, collection: true

        yaml do
          map "format", to: :format
          map "extension", to: :extension
          map "parser_class", to: :parser_class
          map "enabled", to: :enabled
          map "priority", to: :priority
          map "description", to: :description
          map "options", to: :options
        end

        # Check if this parser handles the given extension
        #
        # @param ext [String] File extension (e.g., ".xmi")
        # @return [Boolean] true if this parser handles the extension
        def handles_extension?(ext)
          extension == ext.downcase
        end
      end

      # Transformation options model
      class TransformationOptions < Lutaml::Model::Serializable
        attribute :validate_output, :boolean, default: -> { false }
        attribute :include_diagrams, :boolean, default: -> { true }
        attribute :preserve_ids, :boolean, default: -> { true }
        attribute :resolve_references, :boolean, default: -> { true }
        attribute :strict_mode, :boolean, default: -> { false }

        yaml do
          map "validate_output", to: :validate_output
          map "include_diagrams", to: :include_diagrams
          map "preserve_ids", to: :preserve_ids
          map "resolve_references", to: :resolve_references
          map "strict_mode", to: :strict_mode
        end
      end

      # Format detection rules model
      class FormatDetection < Lutaml::Model::Serializable
        attribute :use_file_extension, :boolean, default: -> { true }
        attribute :use_content_sniffing, :boolean, default: -> { true }
        attribute :fallback_parser, :string
        attribute :magic_bytes, :string, collection: true

        yaml do
          map "use_file_extension", to: :use_file_extension
          map "use_content_sniffing", to: :use_content_sniffing
          map "fallback_parser", to: :fallback_parser
          map "magic_bytes", to: :magic_bytes
        end
      end

      # Error handling configuration
      class ErrorHandling < Lutaml::Model::Serializable
        attribute :strategy, :string, default: -> { "continue" }
        attribute :log_errors, :boolean, default: -> { true }
        attribute :max_errors, :integer, default: -> { 10 }
        attribute :fail_fast, :boolean, default: -> { false }

        yaml do
          map "strategy", to: :strategy
          map "log_errors", to: :log_errors
          map "max_errors", to: :max_errors
          map "fail_fast", to: :fail_fast
        end
      end

      attribute :version, :string
      attribute :description, :string
      attribute :parsers, ParserConfig, collection: true
      attribute :transformation_options, TransformationOptions
      attribute :format_detection, FormatDetection
      attribute :error_handling, ErrorHandling

      yaml do
        map "version", to: :version
        map "description", to: :description
        map "parsers", to: :parsers
        map "transformation_options", to: :transformation_options
        map "format_detection", to: :format_detection
        map "error_handling", to: :error_handling
      end

      class << self
        # Load configuration from YAML file
        #
        # @param config_path [String, nil] Path to configuration file
        #   Defaults to config/model_transformations.yml
        # @return [Configuration] The loaded configuration
        # @raise [Errno::ENOENT] if config file not found
        # @raise [Lutaml::Model::Error] if YAML is invalid
        def load(config_path = nil)
          config_path ||= default_config_path

          unless File.exist?(config_path)
            # Create default configuration if none exists
            return create_default_configuration
          end

          yaml_content = File.read(config_path)
          from_yaml(yaml_content)
        end

        # Get default configuration file path
        #
        # @return [String] Path to default config file
        def default_config_path
          File.expand_path("../../../config/model_transformations.yml", __dir__)
        end

        # Create default configuration when no config file exists
        #
        # @return [Configuration] Default configuration instance
        def create_default_configuration
          new.tap do |config|
            config.version = "1.0"
            config.description = "Default Model Transformations Configuration"

            # Default parsers
            config.parsers = [
              create_xmi_parser_config,
              create_qea_parser_config,
            ]

            # Default options
            config.transformation_options = TransformationOptions.new
            config.format_detection = FormatDetection.new
            config.error_handling = ErrorHandling.new
          end
        end

        private

        # Create default XMI parser configuration
        #
        # @return [ParserConfig] XMI parser configuration
        def create_xmi_parser_config
          ParserConfig.new.tap do |parser|
            parser.format = "xmi"
            parser.extension = ".xmi"
            parser.parser_class = "Lutaml::ModelTransformations::Parsers::XmiParser"
            parser.enabled = true
            parser.priority = 100
            parser.description = "XML Metadata Interchange parser"
            parser.options = ["validate_xml", "resolve_references"]
          end
        end

        # Create default QEA parser configuration
        #
        # @return [ParserConfig] QEA parser configuration
        def create_qea_parser_config
          ParserConfig.new.tap do |parser|
            parser.format = "qea"
            parser.extension = ".qea"
            parser.parser_class = "Lutaml::ModelTransformations::Parsers::QeaParser"
            parser.enabled = true
            parser.priority = 90
            parser.description = "Enterprise Architect database parser"
            parser.options = ["include_diagrams", "resolve_references"]
          end
        end
      end

      # Get list of enabled parsers, sorted by priority
      #
      # @return [Array<ParserConfig>] Array of enabled parser configurations
      def enabled_parsers
        parsers&.select(&:enabled)&.sort_by { |p| -p.priority } || []
      end

      # Get parser configuration by format name
      #
      # @param format [String] The format name (e.g., "xmi", "qea")
      # @return [ParserConfig, nil] The parser configuration or nil if not found
      def parser_config_for(format)
        parsers&.find { |p| p.format == format.downcase }
      end

      # Get parser configuration by file extension
      #
      # @param extension [String] The file extension (e.g., ".xmi", ".qea")
      # @return [ParserConfig, nil] The parser configuration or nil if not found
      def parser_config_for_extension(extension)
        normalized_ext = extension.downcase
        normalized_ext = ".#{normalized_ext}" unless normalized_ext.start_with?(".")

        enabled_parsers.find { |p| p.handles_extension?(normalized_ext) }
      end

      # Check if a format is enabled
      #
      # @param format [String] The format name
      # @return [Boolean] true if format is enabled
      def format_enabled?(format)
        parser = parser_config_for(format)
        parser&.enabled == true
      end

      # Get all enabled format names
      #
      # @return [Array<String>] Array of enabled format names
      def enabled_formats
        enabled_parsers.map(&:format)
      end

      # Get all supported file extensions
      #
      # @return [Array<String>] Array of supported extensions
      def supported_extensions
        enabled_parsers.map(&:extension).compact
      end

      # Check if content sniffing is enabled
      #
      # @return [Boolean] true if content sniffing should be used
      def content_sniffing_enabled?
        format_detection&.use_content_sniffing == true
      end

      # Check if file extension detection is enabled
      #
      # @return [Boolean] true if file extension should be used for detection
      def file_extension_detection_enabled?
        format_detection&.use_file_extension == true
      end

      # Get fallback parser when format detection fails
      #
      # @return [String, nil] The fallback parser class name
      def fallback_parser
        format_detection&.fallback_parser
      end

      # Get transformation options with defaults
      #
      # @return [TransformationOptions] Transformation options
      def transformation_options
        @transformation_options ||= TransformationOptions.new
      end

      # Get error handling configuration with defaults
      #
      # @return [ErrorHandling] Error handling configuration
      def error_handling
        @error_handling ||= ErrorHandling.new
      end

      # Merge with another configuration (this takes precedence)
      #
      # @param other [Configuration] Configuration to merge with
      # @return [Configuration] New merged configuration
      def merge(other)
        merged = self.class.new

        # Basic attributes
        merged.version = version || other.version
        merged.description = description || other.description

        # Merge parsers (this config takes precedence)
        merged.parsers = merge_parsers(other.parsers)

        # Use this config's options, fallback to other
        merged.transformation_options = transformation_options || other.transformation_options
        merged.format_detection = format_detection || other.format_detection
        merged.error_handling = error_handling || other.error_handling

        merged
      end

      private

      # Merge parser configurations
      #
      # @param other_parsers [Array<ParserConfig>] Other parsers to merge
      # @return [Array<ParserConfig>] Merged parser list
      def merge_parsers(other_parsers)
        return parsers unless other_parsers
        return other_parsers unless parsers

        # Create a hash of this config's parsers by format
        our_parsers = {}
        parsers.each do |parser|
          our_parsers[parser.format] = parser
        end

        # Add other parsers that we don't have
        merged = parsers.dup
        other_parsers.each do |other_parser|
          unless our_parsers.key?(other_parser.format)
            merged << other_parser
          end
        end

        merged
      end
    end
  end
end
