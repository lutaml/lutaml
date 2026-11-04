# frozen_string_literal: true

module Expressir
  module Commands
    class NonAsciiCharacter
      attr_reader :char, :hex, :utf8, :is_math, :replacement,
                  :replacement_type, :occurrences

      def initialize(char, hex, utf8, is_math, replacement, replacement_type)
        @char = char
        @hex = hex
        @utf8 = utf8
        @is_math = is_math
        @replacement = replacement
        @replacement_type = replacement_type
        @occurrences = []
      end

      def add_occurrence(line_number, column, line)
        @occurrences << {
          line_number: line_number,
          column: column,
          line: line,
        }
      end

      def replacement_text
        @is_math ? "AsciiMath: #{@replacement}" : "ISO 10303-11: #{@replacement}"
      end

      def occurrence_count
        @occurrences.size
      end

      def to_h
        {
          character: @char,
          hex: @hex,
          utf8: @utf8,
          is_math: @is_math,
          replacement_type: @replacement_type,
          replacement: @replacement,
          occurrence_count: occurrence_count,
          occurrences: @occurrences,
        }
      end
    end
  end
end
