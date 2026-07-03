# frozen_string_literal: true

module Lutaml
  module Qea
    module Validation
      module Formatters
        # Formats validation results as human-readable text with colors
        #
        # @example Basic usage
        #   formatter = TextFormatter.new(result)
        #   puts formatter.format
        #
        # @example Without color
        #   formatter = TextFormatter.new(result, color: false)
        #   puts formatter.format
        class TextFormatter
          attr_reader :result, :options

          # Creates a new text formatter
          #
          # @param result [ValidationResult] The validation result to format
          # @param options [Hash] Formatting options
          # @option options [Boolean] :color Enable colored output
          # (default: true)
          # @option options [Boolean] :verbose Show all messages
          # (default: false)
          # @option options [Integer] :limit Maximum messages per category
          def initialize(result: nil, **options)
            @result = result
            @options = {
              color: true,
              verbose: false,
              limit: nil,
            }.merge(options)
          end

          # Formats the validation result as text
          #
          # @return [String] Formatted text output
          def format # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
            lines = []
            lines << header
            lines << ""
            lines << summary
            lines << ""

            if result.has_errors?
              lines << section_header("ERRORS", result.errors.size)
              lines << format_messages(result.errors)
              lines << ""
            end

            if result.has_warnings?
              lines << section_header("WARNINGS", result.warnings.size)
              lines << format_messages(result.warnings)
              lines << ""
            end

            if result.has_info? && options[:verbose]
              lines << section_header("INFO", result.info.size)
              lines << format_messages(result.info)
              lines << ""
            end

            lines << footer
            lines.join("\n")
          end

          private

          # Formats the header
          #
          # @return [String]
          def header
            line = "=" * 80
            title = "QEA VALIDATION REPORT"
            if options[:color]
              "#{line}\n#{colorize(title, :cyan, bold: true)}\n#{line}"
            else
              "#{line}\n#{title}\n#{line}"
            end
          end

          # Formats the summary
          #
          # @return [String]
          def summary # rubocop:disable Metrics/AbcSize
            status = if result.valid?
                       colorize("✓ VALID", :green, bold: true)
                     elsif result.has_errors?
                       colorize("✗ INVALID", :red, bold: true)
                     else
                       colorize("⚠ WARNINGS", :yellow, bold: true)
                     end

            [
              "Status: #{status}",
              "",
              "Messages:",
              "  Errors:   #{colorize(result.errors.size.to_s, :red)}",
              "  Warnings: #{colorize(result.warnings.size.to_s, :yellow)}",
              "  Info:     #{result.info.size}",
            ].join("\n")
          end

          # Formats a section header
          #
          # @param title [String] Section title
          # @param count [Integer] Message count
          # @return [String]
          def section_header(title, count)
            color = case title
                    when "ERRORS" then :red
                    when "WARNINGS" then :yellow
                    else :cyan
                    end

            colorize("#{title} (#{count}):", color, bold: true)
          end

          # Formats messages grouped by category
          #
          # @param messages [Array<ValidationMessage>] Messages to format
          # @return [String]
          def format_messages(messages) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
            lines = []
            messages_to_show = apply_limit(messages)

            messages_to_show.group_by(&:category).each do |category, msgs|
              category_name = format_category(category)
              lines << colorize("  #{category_name} (#{msgs.size}):", :cyan)
              lines << ""

              msgs.each do |msg|
                lines << format_message(msg)
                lines << ""
              end
            end

            if options[:limit] && messages.size > options[:limit]
              remaining = messages.size - options[:limit]
              lines << colorize(
                "  ... and #{remaining} more (use --verbose to see all)",
                :yellow,
              )
            end

            lines.join("\n")
          end

          # Formats a single message
          #
          # @param message [ValidationMessage] Message to format
          # @return [String]
          def format_message(message)
            icon = severity_icon(message.severity)
            entity_info = if message.entity_name
                            "#{message.entity_type}:#{message.entity_name}"
                          else
                            message.entity_type.to_s
                          end

            [
              "    #{icon} #{colorize(entity_info, :blue)}",
              "      #{message.message}",
              "      ID: #{message.entity_id}",
            ].join("\n")
          end

          # Formats the footer
          #
          # @return [String]
          def footer
            "=" * 80
          end

          # Applies message limit
          #
          # @param messages [Array<ValidationMessage>]
          # @return [Array<ValidationMessage>]
          def apply_limit(messages)
            return messages unless options[:limit]

            messages.first(options[:limit])
          end

          # Formats a category name
          #
          # @param category [Symbol] Category symbol
          # @return [String]
          def format_category(category)
            category.to_s.split("_").map(&:capitalize).join(" ")
          end

          # Returns an icon for the severity level
          #
          # @param severity [Symbol] Severity level
          # @return [String]
          def severity_icon(severity)
            case severity
            when :error then colorize("✗", :red)
            when :warning then colorize("⚠", :yellow)
            when :info then colorize("ℹ", :blue)
            else "•"
            end
          end

          # Colorizes text if color is enabled
          #
          # @param text [String] Text to colorize
          # @param color [Symbol] Color name
          # @param bold [Boolean] Make text bold
          # @return [String]
          def colorize(text, color = nil, bold: false) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/MethodLength
            return text unless options[:color]

            codes = []
            codes << 1 if bold

            codes << case color
                     when :red then 31
                     when :green then 32
                     when :yellow then 33
                     when :blue then 34
                     when :cyan then 36
                     else 0
                     end

            "\e[#{codes.join(';')}m#{text}\e[0m"
          end
        end
      end
    end
  end
end
