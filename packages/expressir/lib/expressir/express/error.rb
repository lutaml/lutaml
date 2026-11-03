# frozen_string_literal: true

require "parsanol"

module Expressir
  module Express
    # Module containing all Express-related errors
    module Error
      # Base error class for Express errors
      class ExpressError < StandardError; end

      # Error raised when a schema file fails to parse
      class SchemaParseFailure < ExpressError
        attr_reader :filename, :original_error, :parse_failure_cause

        # Initialize a new SchemaParseFailure error
        # @param filename [String] The name of the file that failed to parse
        # @param original_error [Parsanol::ParseFailed] The original parsing error
        def initialize(filename, original_error)
          @filename = filename
          @original_error = original_error
          @parse_failure_cause = original_error.is_a?(Parsanol::ParseFailed) ? original_error.parse_failure_cause : nil
          super("Failed to parse schema in file '#{filename}': #{original_error.message}")
        end
      end

      # Error raised when there's a version mismatch in the cache
      class CacheVersionMismatchError < ExpressError
        attr_reader :cache_version, :expressir_version

        # Initialize a new CacheVersionMismatchError
        # @param cache_version [String] The version of the cache file
        # @param expressir_version [String] The current Expressir version
        def initialize(cache_version, expressir_version)
          @cache_version = cache_version
          @expressir_version = expressir_version
          super("Cache version mismatch, cache version is #{cache_version}, Expressir version is #{expressir_version}")
        end
      end

      # Error raised when a cache file is not a valid cache file or fails integrity validation
      class CacheCorruptedError < ExpressError
        def initialize(message = "Cache file is corrupted or not a valid Expressir cache file")
          super
        end
      end

      # Error raised when parallel file parsing loses a worker or its data
      class ParallelParseError < ExpressError
        def initialize(message = "Parallel parsing failed")
          super
        end
      end

      # Error raised when streaming parsing is requested but unavailable.
      # The streaming paths require a parsanol release whose
      # parse_with_builder is stable; parse_fresh cannot parse EXPRESS
      # without packrat memoization (see parsanol-ruby#52).
      class StreamingUnsupportedError < ExpressError
        def initialize(message = "Streaming parsing is not supported by the installed parsanol release")
          super
        end
      end

      # Base class for visitor-related errors
      class VisitorError < ExpressError; end

      # Error raised when visitor encounters invalid state
      class VisitorInvalidStateError < VisitorError
        # Initialize a new VisitorInvalidStateError
        # @param message [String] Additional error information
        def initialize(message = "Invalid state")
          super("Visitor error: #{message}")
        end
      end

      # Error raised when visitor encounters invalid input
      class VisitorInvalidInputError < VisitorError
        # Initialize a new VisitorInvalidInputError
        # @param message [String] Additional error information
        def initialize(message)
          super("Invalid input error: #{message}")
        end
      end

      # Error raised when a required method is missing
      class FormatterMethodMissingError < ExpressError
        # Initialize a new FormatterMethodMissingError
        # @param formatter [String] Name of the formatter
        # @param method [String] Name of the missing method
        def initialize(formatter, method = nil)
          method_msg = method ? " Missing method: #{method}" : " Missing required method."
          super("Formatter error in #{formatter}.#{method_msg}")
        end
      end

      # Error raised when an unknown AST node type is encountered
      class UnknownNodeTypeError < ExpressError
        attr_reader :node_type

        # Initialize a new UnknownNodeTypeError
        # @param node_type [Symbol] The unknown node type
        def initialize(node_type)
          @node_type = node_type
          super("Unknown AST node type: #{node_type}")
        end
      end

      # Error raised when reference resolution fails
      class VisitorReferenceResolutionError < VisitorError
        attr_reader :source, :reference

        # Initialize a new VisitorReferenceResolutionError
        # @param source [String] Source of the reference
        # @param reference [String] The reference that failed to resolve
        def initialize(source, reference)
          @source = source
          @reference = reference
          super("Failed to resolve reference '#{reference}' from '#{source}'")
        end
      end
    end
  end
end
