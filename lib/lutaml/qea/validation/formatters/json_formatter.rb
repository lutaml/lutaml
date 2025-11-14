# frozen_string_literal: true

require "json"

module Lutaml
  module Qea
    module Validation
      module Formatters
        # Formats validation results as JSON for machine consumption
        #
        # @example Basic usage
        #   formatter = JsonFormatter.new(result)
        #   puts formatter.format
        #
        # @example Pretty printed
        #   formatter = JsonFormatter.new(result, pretty: true)
        #   puts formatter.format
        class JsonFormatter
          attr_reader :result, :options

          # Creates a new JSON formatter
          #
          # @param result [ValidationResult] The validation result to format
          # @param options [Hash] Formatting options
          # @option options [Boolean] :pretty Pretty print JSON (default: false)
          def initialize(result: nil, **options)
            @result = result
            @options = {
              pretty: false,
            }.merge(options)
          end

          # Formats the validation result as JSON
          #
          # @return [String] JSON output
          def format
            data = build_data

            if options[:pretty]
              JSON.pretty_generate(data)
            else
              JSON.generate(data)
            end
          end

          private

          # Builds the data structure for JSON output
          #
          # @return [Hash]
          def build_data
            {
              summary: build_summary,
              messages: build_messages,
              by_category: build_by_category,
              by_severity: build_by_severity,
            }
          end

          # Builds the summary section
          #
          # @return [Hash]
          def build_summary
            {
              valid: result.valid?,
              total_messages: result.messages.size,
              error_count: result.errors.size,
              warning_count: result.warnings.size,
              info_count: result.info.size,
            }
          end

          # Builds the messages array
          #
          # @return [Array<Hash>]
          def build_messages
            result.messages.map do |message|
              {
                severity: message.severity,
                category: message.category,
                entity_type: message.entity_type,
                entity_id: message.entity_id,
                entity_name: message.entity_name,
                message: message.message,
                context: message.context,
              }
            end
          end

          # Builds messages grouped by category
          #
          # @return [Hash]
          def build_by_category
            result.messages.group_by(&:category).transform_values do |msgs|
              {
                count: msgs.size,
                messages: msgs.map(&:message),
              }
            end
          end

          # Builds messages grouped by severity
          #
          # @return [Hash]
          def build_by_severity
            {
              errors: format_severity_group(result.errors),
              warnings: format_severity_group(result.warnings),
              info: format_severity_group(result.info),
            }
          end

          # Formats a group of messages by severity
          #
          # @param messages [Array<ValidationMessage>]
          # @return [Hash]
          def format_severity_group(messages)
            {
              count: messages.size,
              by_category: messages.group_by(&:category).transform_values do |msgs|
                msgs.map do |msg|
                  {
                    entity_type: msg.entity_type,
                    entity_id: msg.entity_id,
                    entity_name: msg.entity_name,
                    message: msg.message,
                  }
                end
              end,
            }
          end
        end
      end
    end
  end
end
