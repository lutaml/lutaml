# frozen_string_literal: true

module Expressir
  module Express
    # Splits multi-schema EXPRESS source into individual schema blocks.
    #
    # A hand-rolled state machine that skips comments (`(* ... *)`) and
    # string literals, tracks SCHEMA/END_SCHEMA depth, and returns one
    # block per schema declaration. Retained for the future streaming
    # parse path (see TODO.max-perf/02) that parses each schema
    # independently with a fresh memory arena.
    #
    # Extracted from the outer Parser class (TODO.bugs/09) so block-
    # scanning logic lives in one focused module behind one interface.
    module SchemaBlockScanner
      END_SCHEMA_KEYWORD = "END_SCHEMA"
      SCHEMA_KEYWORD = "SCHEMA"
      WHITESPACE_CHARS = [" ", "\t", "\n", "\r"].freeze

      module_function

      # Extract individual schema blocks from EXPRESS source.
      #
      # Uses a state machine to properly handle nested comments and strings.
      #
      # @param source [String] EXPRESS source
      # @return [Array<Hash>] Array of {name:, source:, start_pos:, end_pos:}
      #   for each schema block found.
      def extract_schema_blocks(source)
        blocks = []
        pos = 0
        len = source.length

        while pos < len
          pos = skip_ws_and_comments(source, pos)
          break if pos >= len

          if source[pos..].start_with?(SCHEMA_KEYWORD)
            result = parse_schema_block(source, pos)
            if result
              blocks << result
              pos = result[:end_pos]
              next
            end
          end

          pos += 1
        end

        blocks
      end

      def parse_schema_block(source, start_pos)
        return nil unless source[start_pos..].start_with?(SCHEMA_KEYWORD)

        pos = start_pos + SCHEMA_KEYWORD.length
        pos = skip_spaces(source, pos)

        name_start = pos
        while pos < source.length && (source[pos] =~ /[a-zA-Z0-9_]/ || source[pos] == "_")
          pos += 1
        end
        schema_name = source[name_start...pos]
        return nil if schema_name.empty?

        depth = 1
        search_pos = pos
        end_pos = nil

        while search_pos < source.length
          if source[search_pos] == '"'
            search_pos += 1
            while search_pos < source.length && source[search_pos] != '"'
              search_pos += 1
            end
            search_pos += 1
          elsif source[search_pos] == "(" && source[search_pos + 1] == "*"
            search_pos += 2
            while search_pos < source.length && !(source[search_pos] == "*" && source[search_pos + 1] == ")")
              search_pos += 1
            end
            search_pos += 2
          elsif source[search_pos..].start_with?(END_SCHEMA_KEYWORD)
            depth -= 1
            if depth.zero?
              end_pos = search_pos + END_SCHEMA_KEYWORD.length
              pos = end_pos
              pos = skip_spaces(source, pos)
              pos += 1 if source[pos] == ";"
              break
            end
            search_pos += END_SCHEMA_KEYWORD.length
          else
            search_pos += 1
          end
        end

        return nil unless end_pos

        {
          name: schema_name,
          source: source[start_pos...end_pos],
          start_pos: start_pos,
          end_pos: pos,
        }
      end

      def skip_spaces(source, pos)
        while pos < source.length && WHITESPACE_CHARS.include?(source[pos])
          pos += 1
        end
        pos
      end

      def skip_ws_and_comments(source, pos)
        len = source.length
        while pos < len
          c = source[pos]
          if WHITESPACE_CHARS.include?(c)
            pos += 1
          elsif c == "(" && source[pos + 1] == "*"
            pos += 2
            while pos < len - 1 && !(source[pos] == "*" && source[pos + 1] == ")")
              pos += 1
            end
            pos += 2
          else
            break
          end
        end
        pos
      end

      private_class_method :parse_schema_block, :skip_spaces, :skip_ws_and_comments
    end
  end
end
