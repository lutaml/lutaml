# frozen_string_literal: true

module Lutaml
  module Uml
    module Parsers
      # Class for preprocessing dsl ascii file special directives:
      # - include
      class DslPreprocessor
        attr_reader :input_file

        # A `definition { ... }` body, mirroring the grammar: it runs from
        # `definition {` to the first unescaped `}` (`\` escapes the next
        # character; braces do not nest). Used to keep an `include` that appears
        # as literal text inside a definition from being expanded as a directive.
        DEFINITION_BODY = /\bdefinition\s*\{(?:\\.|[^}])*\}/m

        def initialize(input_file)
          @input_file = input_file
        end

        class << self
          def call(input_file)
            new(input_file).call
          end
        end

        def call
          include_root = File.dirname(input_file.path)
          text = input_file.read
          in_definition = definition_line_flags(text)
          text.split("\n").each_with_index.reduce([]) do |res, (line, index)|
            res.push(*process_dsl_line(include_root, line, in_definition[index]))
          end.join("\n")
        end

        private

        # `include` is only expanded at statement position. A line whose content
        # falls inside a `definition { ... }` body is literal text, so leave it
        # untouched — otherwise a definition line beginning with `include` would
        # be misread as a directive.
        def process_dsl_line(include_root, line, in_definition)
          return line if in_definition

          process_include_line(include_root, line)
        end

        # @return [Array<Boolean>] per line, whether the line's content is inside
        #   a definition body (indexed to match the read text split on newlines).
        def definition_line_flags(text)
          flags = Array.new(text.count("\n") + 1, false)
          pos = 0
          while (match = DEFINITION_BODY.match(text, pos))
            mark_definition_lines(flags, text, match)
            pos = match.end(0)
          end
          flags
        end

        def mark_definition_lines(flags, text, match)
          first = text[0...match.begin(0)].count("\n")
          last = text[0...(match.end(0) - 1)].count("\n")
          (first..last).each { |line_index| flags[line_index] = true }
        end

        def process_include_line(include_root, line) # rubocop:disable Metrics/MethodLength
          include_path_match = line.match(/^\s*include\s+(.+)/)
          return line if include_path_match.nil? || line =~ /^\s\*\*/

          path_to_file = include_path_match[1].strip
          unless path_to_file.match?(/^\//)
            path_to_file = File.join(include_root,
                                     path_to_file)
          end
          File.read(path_to_file).split("\n")
        rescue Errno::ENOENT
          puts(
            "No such file or directory @ rb_sysopen - #{path_to_file}, " \
            "include file paths need to be supplied relative to the main " \
            "document",
          )
        end
      end
    end
  end
end
