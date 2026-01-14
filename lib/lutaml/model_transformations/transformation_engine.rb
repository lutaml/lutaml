# frozen_string_literal: true

require_relative "configuration"
require_relative "format_registry"
require_relative "parsers/base_parser"

module Lutaml
  module ModelTransformations
    # Transformation Engine orchestrates the entire model transformation process.
    #
    # This class implements the Facade pattern to provide a simple interface
    # for complex model transformation operations. It coordinates between
    # configuration, format detection, parser selection, and transformation.
    #
    # The engine follows the Dependency Inversion Principle by depending on
    # abstractions (BaseParser interface) rather than concrete implementations.
    #
    # @example Basic usage
    #   engine = TransformationEngine.new
    #   document = engine.parse("model.xmi")
    #
    # @example With custom configuration
    #   config = Configuration.load("my_config.yml")
    #   engine = TransformationEngine.new(config)
    #   document = engine.parse("model.qea")
    class TransformationEngine
      # @return [Configuration] Current configuration
      attr_reader :configuration

      # @return [FormatRegistry] Format registry
      attr_reader :format_registry

      # @return [Array<Hash>] Transformation history
      attr_reader :transformation_history

      # @return [Parser] Parser instance
      attr_reader :current_parser

      # Initialize transformation engine
      #
      # @param configuration [Configuration, nil] Configuration to use
      #   (defaults to auto-loaded configuration)
      def initialize(configuration = nil)
        @configuration = configuration || Configuration.load
        @format_registry = FormatRegistry.new
        @transformation_history = []
        @parser_cache = {}

        # Load parsers from configuration
        setup_parsers
      end

      # Parse a model file into a UML document
      #
      # This is the main entry point for model transformation. It auto-detects
      # the file format and uses the appropriate parser.
      #
      # @param file_path [String] Path to the model file
      # @param options [Hash] Parsing options (merged with configuration)
      # @return [Lutaml::Uml::Document] Parsed UML document
      # @raise [UnsupportedFormatError] if file format is not supported
      # @raise [ParseError] if parsing fails
      def parse(file_path, options = {})
        validate_file_path!(file_path)

        # Detect format and get parser
        parser_class = detect_parser(file_path)
        raise UnsupportedFormatError.new(file_path) unless parser_class

        # Create parser instance with merged options
        merged_options = merge_options(options)
        @current_parser = get_parser_instance(parser_class, merged_options)

        # Record transformation start
        transformation_start = Time.now

        begin
          # Perform parsing
          document = @current_parser.parse(file_path)

          # Record successful transformation
          record_transformation(
            file_path: file_path,
            parser: @current_parser,
            duration: Time.now - transformation_start,
            success: true,
            document: document,
          )

          document
        rescue StandardError => e
          # Record failed transformation
          record_transformation(
            file_path: file_path,
            parser: @current_parser,
            duration: Time.now - transformation_start,
            success: false,
            error: e,
          )

          # Re-raise the error
          raise
        end
      end

      # Auto-detect file format and return appropriate parser class
      #
      # Uses multiple detection strategies:
      # 1. File extension
      # 2. Content detection (magic bytes)
      # 3. Fallback parser from configuration
      #
      # @param file_path [String] Path to the model file
      # @return [Class, nil] Parser class, or nil if format cannot be detected
      def detect_parser(file_path)
        # Strategy 1: File extension detection
        if @configuration.file_extension_detection_enabled?
          parser_class = @format_registry.parser_for_file(file_path)
          return parser_class if parser_class
        end

        # Strategy 2: Content detection
        if @configuration.content_sniffing_enabled?
          parser_class = @format_registry.detect_by_content(file_path)
          return parser_class if parser_class
        end

        # Strategy 3: Fallback parser
        fallback_parser_name = @configuration.fallback_parser
        if fallback_parser_name
          return constantize_class(fallback_parser_name)
        end

        nil
      rescue StandardError
        nil
      end

      # Get list of supported file extensions
      #
      # @return [Array<String>] List of supported extensions
      def supported_extensions
        @format_registry.supported_extensions
      end

      # Check if a file format is supported
      #
      # @param file_path [String] Path to check
      # @return [Boolean] true if format is supported
      def supports_file?(file_path)
        detect_parser(file_path) != nil
      end

      # Register a custom parser for a file extension
      #
      # @param extension [String] File extension (e.g., ".custom")
      # @param parser_class [Class] Parser class implementing BaseParser interface
      # @return [void]
      def register_parser(extension, parser_class)
        @format_registry.register(extension, parser_class)
      end

      # Unregister a parser for a file extension
      #
      # @param extension [String] File extension to unregister
      # @return [Class, nil] The unregistered parser class
      def unregister_parser(extension)
        @format_registry.unregister(extension)
      end

      # Set configuration and reload parsers
      #
      # @param config [Configuration] New configuration
      # @return [void]
      def configuration=(config)
        @configuration = config
        @parser_cache.clear
        setup_parsers
      end

      # Get comprehensive transformation statistics
      #
      # @return [Hash] Statistics about transformations
      def statistics
        successful_transformations = @transformation_history.count do |t|
          t[:success]
        end
        failed_transformations = @transformation_history.count do |t|
          !t[:success]
        end

        {
          total_transformations: @transformation_history.size,
          successful_transformations: successful_transformations,
          failed_transformations: failed_transformations,
          success_rate: calculate_success_rate,
          average_duration: calculate_average_duration,
          supported_extensions: supported_extensions,
          registered_parsers: @format_registry.all_parsers.keys,
          configuration_version: @configuration.version,
        }
      end

      # Clear transformation history
      #
      # @return [void]
      def clear_history
        @transformation_history.clear
      end

      # Get transformation history for a specific file
      #
      # @param file_path [String] Path to the file
      # @return [Array<Hash>] Transformation history entries for the file
      def history_for_file(file_path)
        @transformation_history.select do |entry|
          entry[:file_path] == file_path
        end
      end

      # Get recent transformation failures
      #
      # @param limit [Integer] Maximum number of failures to return
      # @return [Array<Hash>] Recent failure entries
      def recent_failures(limit = 10)
        @transformation_history
          .reject { |entry| entry[:success] }
          .last(limit)
      end

      # Validate configuration and parsers
      #
      # @return [Hash] Validation results
      def validate_setup
        results = {
          configuration_valid: false,
          parsers_loaded: 0,
          parser_errors: [],
          warnings: [],
        }

        # Validate configuration
        begin
          if @configuration&.enabled_parsers&.any?
            results[:configuration_valid] = true
          else
            results[:warnings] << "No enabled parsers in configuration"
          end
        rescue StandardError => e
          results[:parser_errors] << "Configuration error: #{e.message}"
        end

        # Validate each parser
        @format_registry.all_parsers.each_value do |parser_class|
          # Try to create instance to validate
          parser = parser_class.new(configuration: @configuration)
          if parser.respond_to?(:parse)
            results[:parsers_loaded] += 1
          else
            results[:parser_errors] << "Parser #{parser_class} does not implement parse method"
          end
        rescue StandardError => e
          results[:parser_errors] << "Failed to instantiate #{parser_class}: #{e.message}"
        end

        results
      end

      private

      # Setup parsers from configuration
      #
      # @return [void]
      def setup_parsers
        # Clear existing parsers
        @format_registry.clear

        # Load parsers from configuration
        @format_registry.load_from_configuration(@configuration)

        # Load default parsers if none configured
        if @format_registry.supported_extensions.empty?
          @format_registry.load_default_parsers
        end
      end

      # Get parser instance (with caching)
      #
      # @param parser_class [Class] Parser class
      # @param options [Hash] Parser options
      # @return [BaseParser] Parser instance
      def get_parser_instance(parser_class, options)
        cache_key = [parser_class, options.hash]

        @parser_cache[cache_key] ||= parser_class.new(
          configuration: @configuration,
          options: options,
        )
      end

      # Merge options with configuration defaults
      #
      # @param options [Hash] User-provided options
      # @return [Hash] Merged options
      def merge_options(options)
        default_options = {}

        if @configuration.transformation_options
          default_options = {
            validate_output: @configuration.transformation_options.validate_output,
            include_diagrams: @configuration.transformation_options.include_diagrams,
            preserve_ids: @configuration.transformation_options.preserve_ids,
            resolve_references: @configuration.transformation_options.resolve_references,
            strict_mode: @configuration.transformation_options.strict_mode,
          }
        end

        default_options.merge(options)
      end

      # Record transformation in history
      #
      # @param entry [Hash] Transformation entry
      # @return [void]
      def record_transformation(entry)
        # Add timestamp and additional metadata
        full_entry = entry.merge(
          timestamp: Time.now,
          engine_version: self.class.name,
          configuration_version: @configuration.version,
        )

        @transformation_history << full_entry

        # Keep history size manageable (last 1000 entries)
        @transformation_history.shift if @transformation_history.size > 1000
      end

      # Calculate success rate
      #
      # @return [Float] Success rate as percentage
      def calculate_success_rate
        return 0.0 if @transformation_history.empty?

        successful = @transformation_history.count { |t| t[:success] }
        (successful.to_f / @transformation_history.size * 100).round(2)
      end

      # Calculate average transformation duration
      #
      # @return [Float] Average duration in seconds
      def calculate_average_duration
        return 0.0 if @transformation_history.empty?

        total_duration = @transformation_history.sum { |t| t[:duration] || 0 }
        (total_duration / @transformation_history.size).round(3)
      end

      # Validate file path
      #
      # @param file_path [String] File path to validate
      # @raise [ArgumentError] if path is invalid
      def validate_file_path!(file_path)
        raise ArgumentError, "File path cannot be nil" if file_path.nil?
        raise ArgumentError, "File path cannot be empty" if file_path.empty?

        unless File.exist?(file_path)
          raise ArgumentError,
                "File does not exist: #{file_path}"
        end
      end

      # Convert string class name to class constant
      #
      # @param class_name [String] Fully qualified class name
      # @return [Class] The class constant
      def constantize_class(class_name)
        parts = class_name.split("::")
        constant = Object
        parts.each { |part| constant = constant.const_get(part) }
        constant
      rescue NameError
        nil
      end
    end

    # Error class for unsupported file formats
    class UnsupportedFormatError < StandardError
      # @return [String] Path to the unsupported file
      attr_reader :file_path

      # Initialize error
      #
      # @param file_path [String] Path to unsupported file
      def initialize(file_path)
        @file_path = file_path
        extension = File.extname(file_path)
        super("Unsupported file format: #{extension} (file: #{file_path})")
      end
    end
  end
end
