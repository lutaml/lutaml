# frozen_string_literal: true

module Expressir
  module Commands
    class FileViolations
      attr_reader :path, :filename, :directory, :violations

      def initialize(file_path)
        @path = file_path
        @filename = File.basename(file_path)
        @directory = File.dirname(file_path)
        @characters = {}  # Map of characters to NonAsciiCharacter objects
        @violations = []  # List of violations (line, column, etc.)
      end

      def add_violation(line_number, column, match, char_details, line)
        violation = {
          line_number: line_number,
          column: column,
          match: match,
          char_details: char_details,
          line: line,
        }

        @violations << violation

        # Register each character
        char_details.each do |detail|
          char = detail[:char]
          unless @characters[char]
            @characters[char] = NonAsciiCharacter.new(
              char,
              detail[:hex],
              detail[:utf8],
              detail[:is_math],
              detail[:replacement],
              detail[:replacement_type],
            )
          end

          @characters[char].add_occurrence(line_number, column, line)
        end
      end

      def violation_count
        @violations.size
      end

      def unique_characters
        @characters.values
      end

      def display_path
        "#{File.basename(@directory)}/#{@filename}"
      end

      def full_path
        File.expand_path(@path)
      end

      def to_h
        {
          file: display_path,
          count: violation_count,
          non_ascii_characters: unique_characters.map(&:to_h),
        }
      end
    end
  end
end
