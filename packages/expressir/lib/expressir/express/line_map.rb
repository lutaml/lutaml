# frozen_string_literal: true

module Expressir
  module Express
    # Maps byte positions in a source string to 1-based line numbers.
    #
    # Single source of truth for byte→line lookup across the remark pipeline
    # (RemarkScanner and RemarkAttacher both rely on it). Builds an offset
    # table once and answers queries in O(log n) via binary search.
    class LineMap
      # Newline byte (ASCII 0x0A).
      NEWLINE = "\n"

      # @param source_bytes [String] BINARY / ASCII-8BIT encoded source.
      def initialize(source_bytes)
        @offsets = build_offsets(source_bytes)
      end

      # Returns the 1-based line number that contains the given byte position.
      # Returns 1 for position 0 (or any position before the first newline).
      # Returns the last line number for positions past the final newline.
      #
      # @param byte_pos [Integer, nil]
      # @return [Integer] 1-based line number; nil input yields 1.
      def line_number(byte_pos)
        return 1 if byte_pos.nil? || byte_pos <= 0

        idx = @offsets.bsearch_index { |offset| offset > byte_pos }
        idx || @offsets.size
      end

      private

      # Builds the sorted array of byte positions where each line begins.
      # offsets[0] = 0 (line 1 begins at byte 0).
      # offsets[i] = (byte position of the i-th newline) + 1 (line i+1 begins).
      def build_offsets(source_bytes)
        offsets = [0]
        i = 0
        while (i = source_bytes.index(NEWLINE, i))
          offsets << (i + 1)
          i += 1
        end
        offsets
      end
    end
  end
end
