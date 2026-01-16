# frozen_string_literal: true

module Lutaml
  module ModelTransformations
    module Parsers
      # Base parser interface defining the contract for all model format
      # parsers.
      #
      # This abstract base class implements the Template Method pattern and
      # follows the Liskov Substitution Principle - all concrete parsers
      # must be substitutable for this base class.
      #
      # Concrete parsers must implement:
      # - parse_internal: Core parsing logic
      # - supported_extensions: List of supported file extensions
      # - format_name: Human-readable format name
      #
      # @abstract Subclass and implement the abstract methods
      class BaseParser
        # @return [Configuration] Parser configuration
        attr_reader :configuration

        # @return [Hash] Parsing options
        attr_reader :options

        # Initialize parser with configuration and options
        #
        # @param configuration [Configuration] Transformation configuration
        # @param options [Hash] Parsing options
        def initialize(configuration: nil, options: {})
          @configuration = configuration
          @options = default_options.merge(options)
          @errors = []
          @warnings = []
        end

        # Parse a model file into a UML document
        #
        # This is the main public interface method that implements the
        # Template Method pattern. It handles common concerns like validation,
        # error handling, and post-processing.
        #
        # @param file_path [String] Path to the model file
        # @return [Lutaml::Uml::Document] Parsed UML document
        # @raise [ParseError] if parsing fails
        def parse(file_path) # rubocop:disable Metrics/MethodLength
          validate_file!(file_path) if should_validate_input?
          clear_errors_and_warnings

          begin
            # Pre-parsing hook
            before_parse(file_path)

            # Core parsing (implemented by subclasses)
            document = parse_internal(file_path)

            # Post-parsing processing
            document = after_parse(document, file_path)

            # Validate output if requested
            validate_output!(document) if should_validate_output?

            document
          rescue StandardError => e
            handle_parsing_error(e, file_path)
          end
        end

        # Check if this parser can handle the given file
        #
        # @param file_path [String] Path to the file
        # @return [Boolean] true if parser can handle the file
        def can_parse?(file_path) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          extension = File.extname(file_path).downcase
          return true if supported_extensions.include?(extension)

          if respond_to?(:content_patterns) && File.exist?(file_path)
            File.open(file_path, "rb") do |file|
              header = file.read(1024) # Read first 1KB
              return false if header.nil? || header.empty?

              content_patterns.each do |pattern|
                return true if header.match?(pattern)
              end
            end
          end

          false
        end

        # Get parser format name
        #
        # @return [String] Human-readable format name
        # @abstract Implement in subclass
        def format_name
          raise NotImplementedError, "Subclasses must implement #format_name"
        end

        # Get list of supported file extensions
        #
        # @return [Array<String>] List of extensions (e.g., [".xmi", ".xml"])
        # @abstract Implement in subclass
        def supported_extensions
          raise NotImplementedError,
                "Subclasses must implement #supported_extensions"
        end

        # Default parser priority
        def priority
          100
        end

        # Check if parser has any errors
        #
        # @return [Boolean] true if there are parsing errors
        def has_errors?
          !@errors.empty?
        end

        # Check if parser has any warnings
        #
        # @return [Boolean] true if there are parsing warnings
        def has_warnings?
          !@warnings.empty?
        end

        # Get all parsing errors
        #
        # @return [Array<String>] List of error messages
        def errors
          @errors.dup
        end

        # Get all parsing warnings
        #
        # @return [Array<String>] List of warning messages
        def warnings
          @warnings.dup
        end

        # Get parsing statistics
        #
        # @return [Hash] Statistics about the parsing process
        def statistics
          {
            format: format_name,
            errors: @errors.size,
            warnings: @warnings.size,
            options: @options,
          }
        end

        protected

        # Core parsing implementation
        #
        # @param file_path [String] Path to the file to parse
        # @return [Lutaml::Uml::Document] Parsed UML document
        # @abstract Implement in subclass
        def parse_internal(file_path)
          raise NotImplementedError, "Subclasses must implement #parse_internal"
        end

        # Hook called before parsing starts
        #
        # @param file_path [String] Path to the file being parsed
        # @return [void]
        def before_parse(file_path)
          # Default implementation does nothing
          # Subclasses can override for pre-processing
        end

        # Hook called after parsing completes
        #
        # @param document [Lutaml::Uml::Document] Parsed document
        # @param file_path [String] Path to the source file
        # @return [Lutaml::Uml::Document] Processed document
        def after_parse(document, _file_path)
          # Default implementation returns document unchanged
          # Subclasses can override for post-processing
          document
        end

        # Get default parsing options
        #
        # @return [Hash] Default options hash
        def default_options
          {
            validate_input: true,
            validate_output: false,
            include_diagrams: true,
            preserve_ids: true,
            resolve_references: true,
            strict_mode: false,
          }
        end

        # Add an error message
        #
        # @param message [String] Error message
        # @param context [Hash] Additional context information
        # @return [void]
        def add_error(message, context = {})
          error_entry = {
            message: message,
            context: context,
            timestamp: Time.now,
          }
          @errors << error_entry

          # Log error if configuration allows
          log_error(error_entry) if should_log_errors?
        end

        # Add a warning message
        #
        # @param message [String] Warning message
        # @param context [Hash] Additional context information
        # @return [void]
        def add_warning(message, context = {})
          warning_entry = {
            message: message,
            context: context,
            timestamp: Time.now,
          }
          @warnings << warning_entry

          # Log warning if configuration allows
          log_warning(warning_entry) if should_log_errors?
        end

        # Check if input validation is enabled
        #
        # @return [Boolean] true if input should be validated
        def should_validate_input?
          @options[:validate_input]
        end

        # Check if output validation is enabled
        #
        # @return [Boolean] true if output should be validated
        def should_validate_output?
          @options[:validate_output] ||
            @configuration&.transformation_options&.validate_output
        end

        # Check if errors should be logged
        #
        # @return [Boolean] true if errors should be logged
        def should_log_errors?
          @configuration&.error_handling&.log_errors != false
        end

        # Check if parser should fail fast on errors
        #
        # @return [Boolean] true if parser should fail on first error
        def should_fail_fast?
          @configuration&.error_handling&.fail_fast == true
        end

        private

        # Validate input file exists and is readable
        #
        # @param file_path [String] Path to validate
        # @raise [ArgumentError] if file is invalid
        def validate_file!(file_path)
          if file_path.nil? || file_path.empty?
            raise ArgumentError, "File path cannot be nil"
          end

          unless File.exist?(file_path)
            raise ArgumentError, "File does not exist: #{file_path}"
          end

          unless File.readable?(file_path)
            raise ArgumentError, "File is not readable: #{file_path}"
          end
        end

        # Clear accumulated errors and warnings
        #
        # @return [void]
        def clear_errors_and_warnings
          @errors.clear
          @warnings.clear
        end

        # Validate parsing output
        #
        # @param document [Lutaml::Uml::Document] Document to validate
        # @raise [ValidationError] if document is invalid
        def validate_output!(document)
          unless document.is_a?(Lutaml::Uml::Document)
            raise ArgumentError, "Parser must return a Lutaml::Uml::Document"
          end

          # Basic validation - subclasses can override for format-specific
          # validation
          if document.packages.nil? && document.classes.nil?
            add_warning("Document contains no packages or classes")
          end
        end

        # Handle parsing errors according to configuration
        #
        # @param error [StandardError] The error that occurred
        # @param file_path [String] Path to the file being parsed
        # @raise [ParseError] Wrapped parsing error
        def handle_parsing_error(error, file_path) # rubocop:disable Metrics/MethodLength
          error_context = {
            file_path: file_path,
            parser: self.class.name,
            original_error: error.class.name,
          }

          add_error("Failed to parse #{file_path}: #{error.message}",
                    error_context)

          # Re-raise as ParseError with additional context
          raise ParseError.new(
            "Parsing failed for #{file_path}",
            original_error: error,
            parser: self,
            file_path: file_path,
          )
        end

        # Log error entry
        #
        # @param error_entry [Hash] Error entry to log
        # @return [void]
        def log_error(error_entry)
          warn "[#{self.class.name}] ERROR: #{error_entry[:message]}"
        end

        # Log warning entry
        #
        # @param warning_entry [Hash] Warning entry to log
        # @return [void]
        def log_warning(warning_entry)
          warn "[#{self.class.name}] WARNING: #{warning_entry[:message]}"
        end
      end

      # Custom error class for parsing failures
      class ParseError < StandardError
        # @return [StandardError] Original error that caused parsing failure
        attr_reader :original_error

        # @return [BaseParser] Parser instance that failed
        attr_reader :parser

        # @return [String] Path to file that failed to parse
        attr_reader :file_path

        # Initialize parsing error
        #
        # @param message [String] Error message
        # @param original_error [StandardError] Original error
        # @param parser [BaseParser] Parser that failed
        # @param file_path [String] File that failed to parse
        def initialize(
          message, original_error: nil, parser: nil,
          file_path: nil
        )
          super(message)
          @original_error = original_error
          @parser = parser
          @file_path = file_path
        end

        # Get detailed error information
        #
        # @return [Hash] Error details
        def details # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
          {
            message: message,
            file_path: @file_path,
            parser: @parser&.class&.name,
            original_error: @original_error&.class&.name,
            original_message: @original_error&.message,
            backtrace: @original_error&.backtrace&.first(5),
          }
        end
      end
    end
  end
end
