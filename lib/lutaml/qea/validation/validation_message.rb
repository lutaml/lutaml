# frozen_string_literal: true

module Lutaml
  module Qea
    module Validation
      # Represents a single validation message with severity, category, and
      # context information
      #
      # @example Creating an error message
      #   message = ValidationMessage.new(
      #     severity: :error,
      #     category: :missing_reference,
      #     entity_type: :association,
      #     entity_id: "FA86EB3B-198A-4141-83F6-DE9FACC76425",
      #     entity_name: "Association_1",
      #     field: "member_end",
      #     reference: "GPLR_Compression",
      #     message: "member_end references non-existent class",
      #     location: "Package::SubPackage"
      #   )
      class ValidationMessage
        # Severity levels for validation messages
        module Severity
          ERROR = :error     # Breaks integrity, must fix
          WARNING = :warning # May cause issues, should review
          INFO = :info       # Informational, may be intentional
        end

        # Categories of validation issues
        module Category
          MISSING_REFERENCE = :missing_reference
          ORPHANED = :orphaned
          DUPLICATE = :duplicate
          INVALID_TYPE = :invalid_type
          CIRCULAR_REFERENCE = :circular_reference
          MISSING_REQUIRED = :missing_required
          CONSTRAINT_VIOLATION = :constraint_violation
        end

        attr_reader :severity, :category, :entity_type, :entity_id,
                    :entity_name, :field, :reference, :message, :location,
                    :context

        # Creates a new validation message
        #
        # @param severity [Symbol] Message severity (:error, :warning, :info)
        # @param category [Symbol] Category of the issue
        # @param entity_type [Symbol] Type of entity (e.g., :class,
        #   :association)
        # @param entity_id [String] XMI ID or database ID of the entity
        # @param entity_name [String] Human-readable name of the entity
        # @param field [String, nil] Field with the issue
        # @param reference [String, nil] What it's trying to reference
        # @param message [String] Human-readable description
        # @param location [String, nil] Package path or context
        # @param context [Hash] Additional context information
        def initialize( # rubocop:disable Metrics/ParameterLists
          severity:,
          category:,
          entity_type:,
          entity_id:,
          entity_name:,
          message:,
          field: nil,
          reference: nil,
          location: nil,
          context: {}
        )
          @severity = severity
          @category = category
          @entity_type = entity_type
          @entity_id = entity_id
          @entity_name = entity_name
          @field = field
          @reference = reference
          @message = message
          @location = location
          @context = context
        end

        # Checks if this is an error message
        #
        # @return [Boolean]
        def error?
          severity == Severity::ERROR
        end

        # Checks if this is a warning message
        #
        # @return [Boolean]
        def warning?
          severity == Severity::WARNING
        end

        # Checks if this is an info message
        #
        # @return [Boolean]
        def info?
          severity == Severity::INFO
        end

        # Returns a formatted string representation of the message
        #
        # @return [String]
        def to_s # rubocop:disable Metrics/AbcSize
          parts = []
          parts << "#{entity_type.to_s.capitalize} '#{entity_name}'"
          parts << "{#{entity_id}}"
          parts << "└─ #{message}"
          parts << "└─ Field: #{field}" if field
          parts << "└─ Reference: #{reference}" if reference
          parts << "└─ Location: #{location}" if location
          parts.join("\n")
        end

        # Returns a hash representation of the message
        #
        # @return [Hash]
        def to_h # rubocop:disable Metrics/MethodLength
          {
            severity: severity,
            category: category,
            entity_type: entity_type,
            entity_id: entity_id,
            entity_name: entity_name,
            field: field,
            reference: reference,
            message: message,
            location: location,
            context: context,
          }.compact
        end

        # Returns a JSON representation of the message
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
