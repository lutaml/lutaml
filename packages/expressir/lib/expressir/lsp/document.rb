# frozen_string_literal: true

module Expressir
  module Lsp
    # An open document: source text, last good AST, and the LSP position
    # translations that the protocol needs. Offsets crossing the boundary
    # are byte offsets into the UTF-8 text; LSP positions are 0-based
    # UTF-16 line/character pairs.
    class Document
      IDENTIFIER = /[A-Za-z][A-Za-z0-9_]*/
      NAME_WINDOW = 1024

      Token = Struct.new(:text, :start_byte, :byte_length, keyword_init: true) do
        def end_byte
          start_byte + byte_length
        end
      end

      SYMBOL_KINDS = {
        Model::Declarations::Schema => 3,     # Namespace
        Model::Declarations::Entity => 5,     # Class
        Model::Declarations::Type => 26,      # TypeParameter
        Model::Declarations::Function => 12,  # Function
        Model::Declarations::Procedure => 6,  # Method
        Model::Declarations::Rule => 11,      # Interface
        Model::Declarations::Constant => 14,  # Constant
        Model::Declarations::Attribute => 8,  # Field
        Model::Declarations::Variable => 13,  # Variable
      }.freeze

      attr_reader :uri, :path, :text, :file, :parse_error

      def initialize(uri:, text:, path: nil)
        @uri = uri
        @path = path || uri_path(uri)
        @text = text.to_s
        @parse_error = nil
        parse!
      end

      def update(text)
        text = text.to_s
        return if text == @text

        @text = text
        parse!
      end

      def schemas
        Array(@file&.schemas)
      end

      def schema_containing(byte)
        schemas.select { |schema| schema.source_offset.to_i <= byte }
          .max_by(&:source_offset)
      end

      def symbols
        return [] unless @file

        position_index.nodes.filter_map do |entry|
          node = entry[:node]
          kind = SYMBOL_KINDS[node.class]
          next unless kind && node.respond_to?(:id) && node.id && entry[:line]

          {
            "name" => node.id.to_s,
            "kind" => kind,
            "range" => line_range(entry[:line], entry[:end_line] || entry[:line]),
            "selectionRange" => range_for(node),
          }
        end
      end

      def reference_nodes
        nodes_of_type(Model::References::SimpleReference)
      end

      def declaration_nodes
        nodes_of_type(Model::ModelElement).select do |node|
          SYMBOL_KINDS.key?(node.class) && node.respond_to?(:id) && node.id
        end
      end

      def token_at(position)
        byte = byte_offset(position["line"], position["character"])
        return nil unless byte

        line_start = line_starts[position["line"]]
        line_text = text.byteslice(line_start,
                                   line_end_byte(position["line"]) - line_start)
        column = byte - line_start
        matches = line_text.to_s.b.to_enum(:scan, IDENTIFIER)
        matches.each do
          match = Regexp.last_match
          next unless column.between?(match.begin(0), match.end(0))

          return Token.new(text: match[0],
                           start_byte: line_start + match.begin(0),
                           byte_length: match[0].bytesize)
        end
        nil
      end

      def position(byte)
        byte = 0 if byte.nil? || byte.negative?
        byte = text.bytesize if byte > text.bytesize
        line = line_starts.bsearch_index { |start| start > byte }
        line = line ? line - 1 : line_starts.length - 1
        prefix = text.byteslice(line_starts[line], byte - line_starts[line]).to_s
        { "line" => line, "character" => utf16_length(prefix) }
      end

      def range(start_byte, length)
        { "start" => position(start_byte),
          "end" => position(start_byte + length) }
      end

      def range_for(node)
        length = node.respond_to?(:id) && node.id ? node.id.to_s.bytesize : 1
        range(name_offset(node), length)
      end

      def name_offset(node)
        offset = node.source_offset.to_i
        return offset if node.is_a?(Model::Declarations::Attribute)

        if node.respond_to?(:id) && node.id
          window = text.byteslice(offset, NAME_WINDOW).to_s
          match = /\b#{Regexp.escape(node.id.to_s)}\b/i.match(window)
          return offset + match.begin(0) if match
        end
        offset
      end

      def line_range(start_line, end_line)
        start_byte = line_starts[start_line - 1] || text.bytesize
        end_byte = line_end_byte(end_line - 1)
        { "start" => position(start_byte), "end" => position(end_byte) }
      end

      def byte_offset(line, character)
        start = line_starts[line]
        return nil unless start

        byte = start
        units = 0
        text.byteslice(start, line_end_byte(line) - start).to_s.each_char do |char|
          break if units >= character

          units += utf16_code_units(char)
          byte += char.bytesize
        end
        byte
      end

      private

      def parse!
        @file = Expressir::Express::Parser.from_exp(@text,
                                                    include_source: true)
        @collector = nil
        @line_starts = nil
        @parse_error = nil
      rescue StandardError => e
        @parse_error = e
      end

      def position_index
        Express::NodePositionIndex.new(@file, Express::LineMap.new(@text.b))
      end

      def nodes_of_type(type)
        collector.nodes.grep(type)
      end

      def collector
        @collector ||= Collector.new.tap { |instance| instance.visit(@file) }
      end

      class Collector < Express::ModelVisitor
        attr_reader :nodes

        def initialize
          super
          @nodes = []
        end

        def visit(node)
          @nodes << node
          super
        end
      end

      def line_starts
        @line_starts ||= begin
          bytes = @text.b
          starts = [0]
          index = 0
          while (index = bytes.index("\n", index))
            starts << (index + 1)
            index += 1
          end
          starts
        end
      end

      def line_end_byte(line)
        following = line_starts[line + 1]
        following ? following - 1 : @text.bytesize
      end

      def utf16_length(string)
        string.each_char.sum { |char| utf16_code_units(char) }
      end

      def utf16_code_units(char)
        char.ord > 0xFFFF ? 2 : 1
      end

      def uri_path(uri)
        uri.to_s.delete_prefix("file://")
      end
    end
  end
end
