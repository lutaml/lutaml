# frozen_string_literal: true

module Lutaml
  module Xsd
    module Validation
      # Lexical value-space helpers shared by the element-side type rule
      # and the attribute-side type validation: numeric/duration/temporal
      # comparison keys, range-facet comparisons, and content-measured
      # lengths (binary counts octets).
      module ValueSpace
        DurationKey = Struct.new(:months, :seconds) do
          include Comparable

          def <=>(other)
            [months, seconds] <=> [other.months, other.seconds]
          end
        end

        # Comparison keys may be Integers, Floats, Durations,
        # DateTimes, or calendar-field ARRAYS — Arrays implement <=>
        # but not the >=/>/<=/< operators, so every comparison goes
        # through the spaceship result. Incomparable keys fail closed
        # (treated as a violation).
        RANGE_FACETS = {
          "min_inclusive" => ->(v, b) { sign_ok?(v, b) { |c| c >= 0 } },
          "min_exclusive" => ->(v, b) { sign_ok?(v, b, &:positive?) },
          "max_inclusive" => ->(v, b) { sign_ok?(v, b) { |c| c <= 0 } },
          "max_exclusive" => ->(v, b) { sign_ok?(v, b, &:negative?) },
        }.freeze

        # @api private
        INTEGER_LEXICAL = /\A[+-]?\d+\z/
        DATE_LEXICAL = /\A(-?\d{4,})-(\d{2})-(\d{2})\z/
        TIME_LEXICAL = /\A(\d{2}):(\d{2}):(\d{2}(?:\.\d+)?)\z/
        BASE64_LEXICAL = %r{\A[A-Za-z0-9+/]*={0,2}\z}
        DURATION_LEXICAL =
          /\A-?P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)D)?(T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+(?:\.\d*)?|\.\d+)S)?)?\z/

        # xsd:integer is unbounded; the fixed-width types carry the
        # XML Schema Part 2 ranges.
        INTEGER_RANGES = {
          "long" => (-(2**63)..((2**63) - 1)),
          "int" => (-(2**31)..((2**31) - 1)),
          "short" => (-(2**15)..((2**15) - 1)),
          "byte" => (-128..127),
          "unsignedLong" => (0..((2**64) - 1)),
          "unsignedInt" => (0..((2**32) - 1)),
          "unsignedShort" => (0..((2**16) - 1)),
          "unsignedByte" => (0..255),
        }.freeze

        INTEGER_SIGNS = {
          "nonPositiveInteger" => ->(n) { n <= 0 },
          "negativeInteger" => lambda(&:negative?),
          "nonNegativeInteger" => ->(n) { n >= 0 },
          "positiveInteger" => lambda(&:positive?),
        }.freeze

        INTEGER_TYPES = (
          ["integer"] + INTEGER_RANGES.keys + INTEGER_SIGNS.keys
        ).freeze

        # Whitespace is collapsed for these types, so every string is a
        # valid lexical form.
        COLLAPSED_STRING_TYPES = %w[string normalizedString token].freeze

        BUILTIN_PREFIXES = %w[xs xsd].freeze

        # xsd:length counts list ITEMS for list types, not characters.
        LIST_BASES = %w[IDREFS ENTITIES NMTOKENS].freeze

        # QName lexicals: NCName or NCName:NCName, with `xmlns` reserved
        # as a prefix. Namespace binding validity is not checked here.
        NCNAME_LEXICAL = /\A[\p{L}_][\p{L}\p{Nd}._-]*\z/

        # gMonthDay admits Feb 29 (no year is known).
        DAYS_IN_MONTH = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30,
                         31].freeze

        class << self
          # @api private
          def sign_ok?(value, bound)
            cmp = value <=> bound
            !cmp.nil? && yield(cmp)
          end
        end

        module_function

        # Own answer for a built-in lexical check: true/false when the
        # value space is decidable here, nil to defer to the engine.
        # The engine's lexical table is lax for the calendar, duration
        # and binary types and over-strict for unbounded integers and
        # whitespace-collapsed strings, so the rule engine answers
        # first and only asks the engine for types it cannot decide.
        #
        # @param type_name [String] type reference, any prefix spelling
        # @param value [String, nil] the lexical value
        # @return [Boolean, nil]
        def lexical_answer(type_name, value)
          prefix, local = type_name.to_s.split(":", 2)
          return nil unless local && BUILTIN_PREFIXES.include?(prefix)

          case local
          when *COLLAPSED_STRING_TYPES
            true
          when *INTEGER_TYPES
            integer_valid?(local, value)
          when "date"
            date_valid?(value)
          when "dateTime"
            date_time_valid?(value)
          when "time"
            time_valid?(value)
          when "gYear", "gYearMonth", "gMonth", "gMonthDay", "gDay"
            calendar_lexical_valid?(local, value)
          when "duration"
            duration_valid?(value)
          when "base64Binary"
            base64_valid?(value)
          when "QName"
            qname_valid?(value)
          end
        end

        def integer_valid?(local, value)
          text = value.to_s.strip
          return false unless text.match?(INTEGER_LEXICAL)

          number = text.to_i
          if (sign = INTEGER_SIGNS[local])
            sign.call(number)
          elsif (range = INTEGER_RANGES[local])
            range.cover?(number)
          else
            true
          end
        end

        def date_valid?(value)
          match = strip_timezone(value).match(DATE_LEXICAL)
          return false unless match

          date_fields_valid?(match[1].to_i, match[2].to_i, match[3].to_i)
        end

        def date_time_valid?(value)
          date_part, time_part, extra = strip_timezone(value).split("T", 3)
          return false unless date_part && time_part && extra.nil?

          match = date_part.match(DATE_LEXICAL)
          return false unless match

          date_fields_valid?(match[1].to_i, match[2].to_i, match[3].to_i) &&
            time_valid?(time_part)
        end

        def time_valid?(value)
          match = strip_timezone(value).match(TIME_LEXICAL)
          return false unless match

          hour = match[1].to_i
          minute = match[2].to_i
          second = match[3].to_i
          return false unless hour.between?(0, 24) &&
            minute.between?(0, 59) && second.between?(0, 59)
          return false if hour == 24 && (minute.positive? || second.positive?)

          true
        end

        def calendar_lexical_valid?(local, value)
          text = strip_timezone(value)
          case local
          when "gYear"
            text.match?(/\A-?\d{4,}\z/)
          when "gYearMonth"
            match = text.match(/\A(-?\d{4,})-(\d{2})\z/)
            !match.nil? && match[2].to_i.between?(1, 12)
          when "gMonth"
            # Both the post-erratum `--MM` and the original XSD 1.0
            # `--MM--` spellings appear in the suite.
            match = text.match(/\A--(\d{2})(?:--)?\z/)
            !match.nil? && match[1].to_i.between?(1, 12)
          when "gMonthDay"
            match = text.match(/\A--(\d{2})-(\d{2})\z/)
            return false unless match

            month = match[1].to_i
            day = match[2].to_i
            month.between?(1, 12) && day.between?(1, DAYS_IN_MONTH[month - 1])
          when "gDay"
            match = text.match(/\A---(\d{2})\z/)
            !match.nil? && match[1].to_i.between?(1, 31)
          end
        end

        def base64_valid?(value)
          cleaned = value.to_s.gsub(/\s+/, "")
          return true if cleaned.empty?

          (cleaned.length % 4).zero? && cleaned.match?(BASE64_LEXICAL)
        end

        # A duration needs at least one component, and a `T` designator
        # must introduce at least one time component (`P1Y2MT` is not a
        # lexical duration).
        def duration_valid?(value)
          match = value.to_s.strip.match(DURATION_LEXICAL)
          return false unless match

          date_part = match[1] || match[2] || match[3]
          time_part = match[5] || match[6] || match[7]
          return false if date_part.nil? && time_part.nil?
          return false if match[4] && time_part.nil?

          true
        end

        # The `xmlns` prefix is reserved, so a QName using it is never
        # valid; everything else must be NCName[:NCName]. Namespace
        # binding validity needs the instance context, which this layer
        # does not hold.
        def qname_valid?(value)
          text = value.to_s.strip
          prefix, local = text.split(":", 2)
          local ||= prefix
          return false if prefix == "xmlns"
          return false if local.nil? || local.empty?

          prefix.match?(NCNAME_LEXICAL) && local.match?(NCNAME_LEXICAL)
        end

        def date_fields_valid?(year, month, day)
          return false unless month.between?(1, 12) && day.between?(1, 31)

          require "date"
          Date.valid_date?(year, month, day)
        rescue StandardError
          true
        end

        def strip_timezone(value)
          value.to_s.strip.sub(/\s/, "").delete_suffix("Z")
            .sub(/[+-]\d{2}:\d{2}\z/, "")
        end

        # Range comparisons run in the lexical space of the base type:
        # numeric types compare numerically, durations order by
        # (months, seconds) per XSD 1.0 Appendix E, and the date/time
        # family compares temporally. Derived types whose base is not
        # a built-in name are not range-checked here.
        def range_domain(base)
          case base.to_s.split(":").last
          when "duration" then :duration
          when "date", "dateTime", "time", "gYear", "gYearMonth",
               "gMonth", "gMonthDay", "gDay"
            :temporal
          end
        end

        def facet_key(value, domain)
          case domain
          when :duration then duration_key(value)
          when :temporal then temporal_key(value)
          else numeric_key(value)
          end
        end

        def numeric_key(value)
          Integer(value, 10)
        rescue ArgumentError, TypeError
          Float(value, exception: false)
        end

        # XSD 1.0 Appendix E ordering: durations order by total months,
        # then by total seconds (days count as 24 hours).
        def duration_key(value)
          match = value.to_s.match(
            /\A(-)?P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?((?:\d+(?:\.\d*)?|\.\d+)S)?)?\z/,
          )
          return nil unless match
          return nil unless match[2] || match[3] || match[4] ||
            match[5] || match[6] || match[7]

          sign = match[1] ? -1 : 1
          months = sign * ((match[2].to_i * 12) + match[3].to_i)
          seconds = sign * ((match[4].to_i * 86_400) +
            (match[5].to_i * 3600) + (match[6].to_i * 60) +
            match[7].to_f)
          DurationKey.new(months, seconds)
        end

        # Calendar-derived types order by their fields; each XSD
        # lexical form maps to a comparable numeric tuple. Timezones
        # are stripped (the suite's range facets compare naive
        # values); unparseable forms fall back to DateTime.
        def temporal_key(value)
          text = strip_timezone(value)

          calendar_key(text) || begin
            require "date"
            DateTime.parse(value.to_s)
          end
        rescue StandardError
          nil
        end

        # @return [Array<Integer>, nil] the calendar fields of an XSD
        #   lexical form, or nil when the text is not one
        def calendar_key(text)
          year_month = text.match(/\A(-?\d{4,})-(\d{2})\z/)
          return [year_month[1].to_i, year_month[2].to_i] if year_month

          g_month_day = text.match(/\A--(\d{2})-(\d{2})\z/)
          return [g_month_day[1].to_i, g_month_day[2].to_i] if g_month_day

          g_day = text.match(/\A---(\d{2})\z/)
          return [g_day[1].to_i] if g_day

          # Both the post-erratum `--MM` and the original `--MM--`
          # spellings are in the suite.
          g_month = text.match(/\A--(\d{2})(?:--)?\z/)
          return [g_month[1].to_i] if g_month

          year = text.match(/\A(-?\d{4,})\z/)
          return [year[1].to_i] if year

          nil
        end

        # Length units follow the base type: binary types measure octets,
        # list types count items — including named types whose chain
        # reaches a list (stG002: maxLength on a restriction of a list
        # of integers counts entries).
        def measured_length(value, restriction, repository: nil,
                            base_local: nil)
          base = base_local || restriction.base.to_s.split(":").last
          text = value.to_s
          case base
          when "hexBinary"
            text.length / 2
          when "base64Binary"
            cleaned = text.gsub(/\s+/, "")
            (cleaned.length * 3 / 4) - cleaned.count("=")
          when *LIST_BASES
            text.split(/\s+/).reject(&:empty?).length
          else
            if repository && list_derived?(base, repository)
              text.split(/\s+/).reject(&:empty?).length
            else
              text.length
            end
          end
        end

        # @return [Boolean]
        def list_derived?(local, repository, depth = 0)
          return false if depth > 8

          type = repository.resolve_named_type(local)
          return false unless
            type.is_a?(Lutaml::Xml::Schema::Xsd::SimpleType)

          if type.list
            true
          elsif type.restriction
            list_derived?(
              type.restriction.base.to_s.split(":").last, repository,
              depth + 1
            )
          else
            false
          end
        end
      end
    end
  end
end
