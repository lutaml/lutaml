# frozen_string_literal: true

require_relative "validation_message"

module Lutaml
  module Qea
    module Validation
      # Collects and organizes validation messages, providing summary
      # statistics and filtering capabilities
      #
      # @example Basic usage
      #   result = ValidationResult.new
      #   result.add_error(
      #     category: :missing_reference,
      #     entity_type: :association,
      #     entity_id: "123",
      #     entity_name: "MyAssociation",
      #     message: "member_end references non-existent class"
      #   )
      #   puts result.summary
      class ValidationResult
        attr_reader :messages

        def initialize
          @messages = []
        end

        # Adds an error message to the result
        #
        # @param args [Hash] Message attributes (see ValidationMessage)
        # @return [ValidationMessage] The created message
        def add_error(**args)
          add_message(severity: :error, **args)
        end

        # Adds a warning message to the result
        #
        # @param args [Hash] Message attributes (see ValidationMessage)
        # @return [ValidationMessage] The created message
        def add_warning(**args)
          add_message(severity: :warning, **args)
        end

        # Adds an info message to the result
        #
        # @param args [Hash] Message attributes (see ValidationMessage)
        # @return [ValidationMessage] The created message
        def add_info(**args)
          add_message(severity: :info, **args)
        end

        # Adds a message to the result
        #
        # @param args [Hash] Message attributes (see ValidationMessage)
        # @return [ValidationMessage] The created message
        def add_message(**args)
          message = ValidationMessage.new(**args)
          @messages << message
          message
        end

        # Checks if there are any error messages
        #
        # @return [Boolean]
        def has_errors?
          @messages.any?(&:error?)
        end

        # Checks if there are any warning messages
        #
        # @return [Boolean]
        def has_warnings?
          @messages.any?(&:warning?)
        end

        # Checks if there are any info messages
        #
        # @return [Boolean]
        def has_info?
          @messages.any?(&:info?)
        end

        # Checks if the result is valid (no errors)
        #
        # @return [Boolean]
        def valid?
          !has_errors?
        end

        # Returns all error messages
        #
        # @return [Array<ValidationMessage>]
        def errors
          @messages.select(&:error?)
        end

        # Returns all warning messages
        #
        # @return [Array<ValidationMessage>]
        def warnings
          @messages.select(&:warning?)
        end

        # Returns all info messages
        #
        # @return [Array<ValidationMessage>]
        def info
          @messages.select(&:info?)
        end

        # Returns messages filtered by severity
        #
        # @param severity [Symbol] The severity to filter by
        # @return [Array<ValidationMessage>]
        def by_severity(severity)
          @messages.select { |m| m.severity == severity }
        end

        # Returns messages filtered by category
        #
        # @param category [Symbol] The category to filter by
        # @return [Array<ValidationMessage>]
        def by_category(category)
          @messages.select { |m| m.category == category }
        end

        # Returns messages filtered by entity type
        #
        # @param entity_type [Symbol] The entity type to filter by
        # @return [Array<ValidationMessage>]
        def by_entity_type(entity_type)
          @messages.select { |m| m.entity_type == entity_type }
        end

        # Returns messages grouped by category
        #
        # @return [Hash<Symbol, Array<ValidationMessage>>]
        def grouped_by_category
          @messages.group_by(&:category)
        end

        # Returns messages grouped by severity
        #
        # @return [Hash<Symbol, Array<ValidationMessage>>]
        def grouped_by_severity
          @messages.group_by(&:severity)
        end

        # Returns messages grouped by entity type
        #
        # @return [Hash<Symbol, Array<ValidationMessage>>]
        def grouped_by_entity_type
          @messages.group_by(&:entity_type)
        end

        # Returns summary statistics
        #
        # @return [Hash]
        def statistics
          {
            total: @messages.size,
            errors: errors.size,
            warnings: warnings.size,
            info: info.size,
            by_category: grouped_by_category.transform_values(&:size),
            by_entity_type: grouped_by_entity_type.transform_values(&:size),
          }
        end

        # Returns a summary string
        #
        # @return [String]
        def summary
          stats = statistics
          [
            "Total Messages: #{stats[:total]}",
            "Errors: #{stats[:errors]}",
            "Warnings: #{stats[:warnings]}",
            "Info: #{stats[:info]}",
          ].join("\n")
        end

        # Merges another result into this one
        #
        # @param other [ValidationResult] The result to merge
        # @return [self]
        def merge!(other)
          @messages.concat(other.messages)
          self
        end

        # Returns a hash representation
        #
        # @return [Hash]
        def to_h
          {
            statistics: statistics,
            messages: @messages.map(&:to_h),
          }
        end

        # Returns a JSON representation
        #
        # @return [String]
        def to_json(*args)
          require "json"
          to_h.to_json(*args)
        end
      end
    end
  end
end
