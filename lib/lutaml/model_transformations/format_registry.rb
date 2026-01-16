# frozen_string_literal: true

module Lutaml
  module ModelTransformations
    # Format Registry manages parser registration and discovery.
    #
    # This class implements the Registry pattern to provide a centralized
    # location for managing format parsers. It follows the Open/Closed Principle
    # by allowing new parsers to be registered without modifying existing code.
    #
    # @example Register a parser
    #   registry = FormatRegistry.new
    #   registry.register(".custom", MyCustomParser)
    #
    # @example Get parser for extension
    #   parser_class = registry.parser_for_extension(".xmi")
    #   parser = parser_class.new
    class FormatRegistry
      # @return [Hash<String, Class>] Map of extensions to parser classes
      attr_reader :parsers

      def initialize
        @parsers = {}
        @extensions = []
        @default_parsers_loaded = false
      end

      # Register a parser for a file extension
      #
      # @param extension [String] File extension (e.g., ".xmi", ".qea")
      # @param parser_class [Class] Parser class implementing BaseParser
      # interface
      # @raise [ArgumentError] if extension or parser_class is invalid
      def register(extension, parser_class) # rubocop:disable Metrics/MethodLength
        if extension.is_a?(Array)
          extension.each { |ext| register(ext, parser_class) }
          return
        end

        validate_extension!(extension)
        validate_parser_class!(parser_class)

        normalized_ext = normalize_extension(extension)
        @parsers[normalized_ext] = parser_class
        unless @extensions.include?(normalized_ext)
          @extensions << normalized_ext
        end
      end

      # Unregister a parser for a file extension
      #
      # @param extension [String] File extension to unregister
      # @return [Class, nil] The unregistered parser class, or nil if not found
      def unregister(extension)
        normalized_ext = normalize_extension(extension)
        @extensions.delete(normalized_ext)
        @parsers.delete(normalized_ext)
      end

      # Auto-register a parser class based on its supported extensions
      #
      # @param parser_class [Class] Parser class inherited from BaseParser
      # @return [void]
      def auto_register_from_parser(parser_class)
        supported_extensions = ""
        if parser_class.new.respond_to?(:supported_extensions)
          supported_extensions = parser_class.new.supported_extensions
        end
        register(supported_extensions, parser_class)
      end

      # Get parser class for a file extension
      #
      # @param extension [String] File extension (e.g., ".xmi", ".qea")
      # @return [Class, nil] Parser class, or nil if not found
      def parser_for_extension(extension)
        # ensure_default_parsers_loaded!
        normalized_ext = normalize_extension(extension)
        @parsers[normalized_ext]
      end

      # Get parser class for a file path
      #
      # @param file_path [String] Path to the file
      # @return [Class, nil] Parser class, or nil if not found
      def parser_for_file(file_path)
        extension = File.extname(file_path)
        parser_for_extension(extension)
      end

      # Check if an extension is supported
      #
      # @param extension [String] File extension to check
      # @return [Boolean] true if extension is supported
      def supports_extension?(extension)
        parser_for_extension(extension) != nil
      end

      # Check if a file is supported
      #
      # @param file_path [String] Path to the file
      # @return [Boolean] true if file format is supported
      def supports_file?(file_path)
        parser_for_file(file_path) != nil
      end

      # Get all supported extensions
      #
      # @return [Array<String>] List of supported file extensions
      def supported_extensions
        # ensure_default_parsers_loaded!
        @parsers.keys.sort
      end

      # Get all registered parsers
      #
      # @return [Hash<String, Class>] Map of extensions to parser classes
      def all_parsers
        # ensure_default_parsers_loaded!
        @parsers.dup
      end

      # Get parsers sorted by priority (highest first)
      #
      # @return [Array<Array(String, Class)>] List of [extension, parser_class]
      def parsers_by_priority
        @parsers.sort_by do |_ext, parser_class|
          if parser_class.method_defined?(:priority)
            parser_class.new.priority
          else
            100
          end
        end.reverse
      end

      # Get all registered extensions
      #
      # @return [Array<String>] List of registered extensions
      def all_extensions
        @extensions.dup
      end

      # Get statistics about registered parsers
      #
      # @return [Hash] Statistics hash
      def statistics # rubocop:disable Metrics/MethodLength
        parsers = @parsers.values.uniq
        total_parsers = parsers.size
        ext_size = @extensions.size

        {
          total_parsers: total_parsers,
          total_extensions: ext_size,
          extensions_per_parser: (ext_size.to_f / total_parsers).round(2),
          parser_details: parsers.map do |parser_class|
            {
              parser: parser_class,
              extensions: parser_class.new.supported_extensions,
              priority: parser_class.new.priority,
              format_name: parser_class.new.format_name,
            }
          end,
        }
      end

      def export_configuration # rubocop:disable Metrics/MethodLength
        {
          exported_at: Time.now,
          parsers: @parsers.map do |parser|
            _ext, parser_class = parser

            {
              parser_class: parser_class,
              extensions: parser_class.new.supported_extensions,
              priority: parser_class.new.priority,
              format: parser_class.new.format_name,
            }
          end,
        }
      end

      # Clear all registered parsers
      #
      # @return [void]
      def clear
        @extensions.clear
        @parsers.clear
        @default_parsers_loaded = false
      end

      # Load parsers from configuration
      #
      # @param configuration [Configuration] Configuration with parser
      # definitions
      # @return [void]
      def load_from_configuration(configuration)
        configuration.enabled_parsers.each do |parser_config|
          parser_class = constantize_parser_class(parser_config.parser_class)
          register(parser_config.extension, parser_class)
        rescue NameError => e
          warn "Warning: Could not load parser " \
               "#{parser_config.parser_class}: #{e.message}"
        end
      end

      # Create a new instance with default parsers loaded
      #
      # @return [FormatRegistry] New registry instance
      def self.with_defaults
        registry = new
        registry.load_default_parsers
        registry
      end

      # Load default parsers (called automatically when needed)
      #
      # @return [void]
      def load_default_parsers # rubocop:disable Metrics/MethodLength
        return if @default_parsers_loaded

        # Load XMI parser if available
        begin
          require_relative "parsers/xmi_parser"
          register(".xmi", Parsers::XmiParser)
        rescue LoadError
          # XMI parser not available, skip
        end

        # Load QEA parser if available
        begin
          require_relative "parsers/qea_parser"
          register(".qea", Parsers::QeaParser)
        rescue LoadError
          # QEA parser not available, skip
        end

        @default_parsers_loaded = true
      end

      # Detect format by file content (magic bytes/signatures)
      #
      # @param file_path [String] Path to the file
      # @return [Class, nil] Parser class based on content detection
      def detect_by_content(file_path) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        # ensure_default_parsers_loaded!
        unless File.exist?(file_path)
          raise ArgumentError, "#{file_path} does not exist!"
        end

        # Read first few bytes to detect format
        File.open(file_path, "rb") do |file|
          header = file.read(1024) # Read first 1KB

          return nil if header.nil? || header.empty?

          # Check header match for content patterns
          @parsers.each do |ext, parser_class|
            if parser_class.new.respond_to? :content_patterns
              parser_klass = parser_class.new
              parser_klass.content_patterns.each do |pattern|
                if header.match?(pattern)
                  return parser_for_extension(ext)
                end
              end
            end
          end

          # Check for XML/XMI signatures
          if header.include?("<?xml") && header.include?("xmi:")
            ensure_default_parsers_loaded!
            return parser_for_extension(".xmi")
          end

          # Check for SQLite database signature (QEA files)
          if header[0..15] == "SQLite format 3\0"
            ensure_default_parsers_loaded!
            return parser_for_extension(".qea")
          end
        end

        nil
      end

      # Get the best parser for a file using multiple detection methods
      #
      # @param file_path [String] Path to the file
      # @param use_content_detection [Boolean] Whether to use content detection
      # @return [Class, nil] Best parser class for the file
      def best_parser_for_file(file_path, use_content_detection: true)
        # First try extension-based detection
        parser = parser_for_file(file_path)
        return parser if parser

        # Fall back to content detection if enabled
        if use_content_detection
          parser = detect_by_content(file_path)
          return parser if parser
        end

        nil
      end

      private

      # Ensure default parsers are loaded
      #
      # @return [void]
      def ensure_default_parsers_loaded!
        load_default_parsers unless @default_parsers_loaded
      end

      # Normalize file extension to lowercase with leading dot
      #
      # @param extension [String] File extension
      # @return [String] Normalized extension
      def normalize_extension(extension)
        ext = extension.to_s.downcase
        ext = ".#{ext}" unless ext.start_with?(".")
        ext
      end

      # Validate file extension format
      #
      # @param extension [String] Extension to validate
      # @raise [ArgumentError] if extension is invalid
      def validate_extension!(extension)
        if extension.nil? || extension.empty?
          raise ArgumentError, "Extension cannot be nil or empty"
        end

        normalized = normalize_extension(extension)
        unless normalized.match?(/^\.[a-z0-9]+(.[a-z0-9]+)?/)
          raise ArgumentError, "Invalid extension format: #{extension}"
        end
      end

      # Validate parser class implements required interface
      #
      # @param parser_class [Class] Parser class to validate
      # @raise [ArgumentError] if parser class is invalid
      def validate_parser_class!(parser_class) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/MethodLength
        # Check if nil
        if parser_class.nil?
          raise ArgumentError, "Parser class cannot be nil"
        end

        # Check if it's a class
        unless parser_class.is_a?(Class)
          raise ArgumentError, "Parser must be a class"
        end

        # Check if class is a subclass of BaseParser
        unless parser_class < Parsers::BaseParser
          raise ArgumentError,
                "Parser class must inherit from BaseParser"
        end

        # Check if class responds to required methods
        required_methods = [:parse]
        missing_methods = required_methods.reject do |method|
          parser_class.method_defined?(method) ||
            parser_class.private_method_defined?(method)
        end

        # Check if any methods are missing
        unless missing_methods.empty?
          raise ArgumentError,
                "Parser class must implement methods: " \
                "#{missing_methods.join(', ')}"
        end
      end

      # Convert string class name to actual class constant
      #
      # @param class_name [String] Fully qualified class name
      # @return [Class] The class constant
      # @raise [NameError] if class cannot be found
      def constantize_parser_class(class_name)
        # Split class name into modules and class
        parts = class_name.split("::")

        # Start from root constant
        constant = Object

        # Navigate through nested modules/classes
        parts.each do |part|
          constant = constant.const_get(part)
        end

        constant
      end
    end
  end
end
