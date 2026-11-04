# frozen_string_literal: true

module Lutaml
  module Xsd
    module Validation
      # ValidationError represents a single validation error or warning
      #
      # This class encapsulates all information about a validation issue,
      # including its code, severity, location, message, and optional
      # suggestions for fixing the issue.
      #
      # @example Create a validation error
      #   error = ValidationError.new(
      #     code: "type_mismatch",
      #     message: "Expected integer, got string",
      #     severity: :error,
      #     location: "/root/element[1]",
      #     context: { expected: "integer", actual: "string" }
      #   )
      #
      # @example Access error details
      #   puts error.code          # => "type_mismatch"
      #   puts error.message       # => "Expected integer, got string"
      #   puts error.severity      # => :error
      #   puts error.location      # => "/root/element[1]"
      class ValidationError
        attr_reader :code, :message, :severity, :location, :context,
                    :suggestion, :line_number

        # Valid severity levels
        SEVERITIES = %i[error warning info].freeze

        # Initialize a new ValidationError
        #
        # @param code [String] Error code identifying the type of error
        # @param message [String] Human-readable error message
        # @param severity [Symbol] Error severity (:error, :warning, :info)
        # @param location [String, nil] XPath or location in the document
        # @param line_number [Integer, nil] Line number if available
        # @param context [Hash, nil] Additional context about the error
        # @param suggestion [String, nil] Suggested fix for the error
        #
        # @raise [ArgumentError] if severity is invalid
        def initialize(code:, message:, severity: :error, location: nil,
                       line_number: nil, context: nil, suggestion: nil)
          validate_severity!(severity)

          @code = code
          @message = message
          @severity = severity
          @location = location
          @line_number = line_number
          @context = context || {}
          @suggestion = suggestion
        end

        # Check if this is an error-level issue
        #
        # @return [Boolean]
        def error?
          @severity == :error
        end

        # Check if this is a warning-level issue
        #
        # @return [Boolean]
        def warning?
          @severity == :warning
        end

        # Check if this is an info-level issue
        #
        # @return [Boolean]
        def info?
          @severity == :info
        end

        # Get formatted location string
        #
        # @return [String]
        def formatted_location
          parts = []
          parts << "Line #{@line_number}" if @line_number
          parts << @location if @location
          parts.empty? ? "(unknown location)" : parts.join(", ")
        end

        # Get detailed error message including location and suggestion
        #
        # @return [String]
        def detailed_message
          parts = []
          parts << "[#{@severity.to_s.upcase}]"
          parts << @code
          parts << "-"
          parts << @message

          result = parts.join(" ")
          result += "\n  Location: #{formatted_location}" if has_location?
          result += "\n  Context: #{format_context}" if @context.any?
          result += "\n  Suggestion: #{@suggestion}" if @suggestion
          result
        end

        # Check if error has location information
        #
        # @return [Boolean]
        def has_location?
          !@location.nil? || !@line_number.nil?
        end

        # Check if error has a suggestion
        #
        # @return [Boolean]
        def has_suggestion?
          !@suggestion.nil? && !@suggestion.empty?
        end

        # Convert error to hash representation
        #
        # @return [Hash]
        def to_h
          {
            code: @code,
            message: @message,
            severity: @severity,
            location: @location,
            line_number: @line_number,
            context: @context,
            suggestion: @suggestion,
          }.compact
        end

        # Convert error to JSON
        #
        # @return [String]
        def to_json(*)
          require "json"
          to_h.to_json(*)
        end

        # String representation
        #
        # @return [String]
        def to_s
          "#{@severity.to_s.upcase}: #{@message} (#{@code})"
        end

        # Detailed string representation with all information
        #
        # @return [String]
        def inspect
          "#<#{self.class.name} code=#{@code.inspect} " \
            "severity=#{@severity.inspect} " \
            "message=#{@message.inspect} " \
            "location=#{@location.inspect}>"
        end

        # Compare errors for equality
        #
        # @param other [ValidationError]
        # @return [Boolean]
        def ==(other)
          return false unless other.is_a?(ValidationError)

          @code == other.code &&
            @message == other.message &&
            @severity == other.severity &&
            @location == other.location
        end

        alias eql? ==

        # Generate hash code for use in hashes and sets
        #
        # @return [Integer]
        def hash
          [@code, @message, @severity, @location].hash
        end

        private

        # Validate severity level
        #
        # @param severity [Symbol] The severity to validate
        # @raise [ArgumentError] if severity is invalid
        def validate_severity!(severity)
          return if SEVERITIES.include?(severity)

          raise ArgumentError,
                "Invalid severity: #{severity.inspect}. " \
                "Must be one of: #{SEVERITIES.join(', ')}"
        end

        # Format context hash for display
        #
        # @return [String]
        def format_context
          @context.map { |k, v| "#{k}=#{v.inspect}" }.join(", ")
        end
      end
    end
  end
end
