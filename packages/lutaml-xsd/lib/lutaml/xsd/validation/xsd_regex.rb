# frozen_string_literal: true

module Lutaml
  module Xsd
    module Validation
      # Translates XSD regular expressions (REC 2004, Appendix F) into
      # Ruby regexps.
      #
      # Dialect differences handled:
      # - XSD patterns are implicitly anchored over the whole string
      # - ^ and $ are literals, not anchors
      # - . matches any character including newlines (multiline flag)
      # - \i and \c are the XML name-start / name character classes
      # - \p{IsBasicLatin}-style block escapes map to Ruby block syntax
      # - character-class subtraction [a-z-[aeiou]] becomes nested
      #   lookaheads with an atomic single-character consume
      #
      #     regex = XsdRegex.to_regexp("[A-Z]{2}-\\d{4}")
      class XsdRegex
        NAME_START_CLASS = "[A-Z_a-z:\\u00C0-\\uD7FF\\uE000-\\uFFFD]"
        NAME_CHAR_CLASS =
          "[A-Z_a-z0-9:\\-.\\u00B7\\u00C0-\\uD7FF\\uE000-\\uFFFD]"
        NAME_START_COMPLEMENT = "[^A-Z_a-z:\\u00C0-\\uD7FF\\uE000-\\uFFFD]"
        NAME_CHAR_COMPLEMENT =
          "[^A-Z_a-z0-9:\\-.\\u00B7\\u00C0-\\uD7FF\\uE000-\\uFFFD]"

        # XSD 1.0 cites Unicode 3.1, where the Ethiopic digits
        # U+1369-U+1371 were Nd; Unicode 4.0.1 demoted them to No. The
        # suite's Unicode-4.0 expectations keep them matching \d
        # (bugzilla 13607), so the legacy set rides along.
        LEGACY_ND = "\\u1369-\\u1371"

        # Blocks Unicode renamed after the Unicode 3.1 names XSD 1.0
        # cites; Ruby only knows the modern names (separators are
        # ignored by Ruby's property lookup, word differences are not).
        BLOCK_RENAMES = {
          "Greek" => "Greek_And_Coptic",
          "CombiningMarksforSymbols" =>
            "Combining_Diacritical_Marks_For_Symbols",
          "PrivateUse" => "Private_Use_Area",
        }.freeze

        # @param pattern [String] an XSD regular expression
        # @return [Regexp] whole-string, multiline Ruby regexp
        def self.to_regexp(pattern)
          new(pattern).to_regexp
        end

        def initialize(pattern)
          @pattern = pattern
        end

        def to_regexp
          Regexp.new("\\A(?:#{translate(@pattern)})\\z", Regexp::MULTILINE)
        end

        private

        # Most of the syntax is identical; the divergences are handled
        # per branch. Class interiors are consumed by scan_class.
        def translate(source)
          out = +""
          i = 0
          while i < source.length
            ch = source[i]
            case ch
            when "\\"
              out << translate_escape(source, i)
              i += escape_length(source, i)
            when "["
              body, next_i = scan_class(source, i)
              out << translate_class_body(body)
              i = next_i
            when "^", "$"
              out << "\\" << ch
              i += 1
            else
              out << ch
              i += 1
            end
          end
          out
        end

        def translate_escape(source, pos)
          rest = source[(pos + 1)..].to_s
          case rest[0]
          when "i" then NAME_START_CLASS
          when "I" then NAME_START_COMPLEMENT
          when "c" then NAME_CHAR_CLASS
          when "C" then NAME_CHAR_COMPLEMENT
          when "d" then "[\\p{Nd}#{LEGACY_ND}]"
          when "D" then "[^\\p{Nd}#{LEGACY_ND}]"
          # Appendix F: \w is every character outside punctuation,
          # separator and other — NOT the Ruby word set (reV class).
          when "w" then "[^\\p{P}\\p{Z}\\p{C}]"
          when "W" then "[\\p{P}\\p{Z}\\p{C}]"
          when "s" then "[\\t\\n\\r ]"
          when "S" then "[^\\t\\n\\r ]"
          when "p", "P"
            close = rest.index("}")
            inner = rest[2...close].to_s
            "\\#{rest[0]}{#{block_name(inner)}}"
          else source[pos, escape_length(source, pos)]
          end
        end

        # \i \c consume two characters; \p{...}/\P{...} span to their
        # closing brace; every other escape is backslash + one character.
        def escape_length(source, pos)
          rest = source[(pos + 1)..].to_s
          if rest.match?(/\A[pP]\{/) && (close = rest.index("}"))
            close + 2
          else
            2
          end
        end

        # @return [Array(String, Integer)] class body and index after the
        #   closing bracket; nested [..] (class subtraction) tracked by
        #   depth so [a-z-[aeiou]] scans as one construct
        def scan_class(source, start)
          i = start + 1
          depth = 0
          body = +"["
          while i < source.length
            ch = source[i]
            case ch
            when "\\"
              body << source[i, 2].to_s
              i += 2
            when "["
              depth += 1
              body << ch
              i += 1
            when "]"
              if depth.positive?
                depth -= 1
                body << ch
                i += 1
              else
                body << "]"
                return [body, i + 1]
              end
            else
              body << ch
              i += 1
            end
          end
          [body, i]
        end

        # Rewrites the inside of a [...] construct: subtraction becomes
        # atomic lookaheads; \i/\c expand; \p{Is...} normalizes.
        def translate_class_body(body)
          inner = body[1..-2]
          idx = inner.rindex("-[")
          if idx
            subtraction(inner[0...idx], inner[(idx + 2)..-2])
          else
            "[#{escape_hyphens(rewrite_escapes(inner))}]"
          end
        end

        # A '-' is a RANGE separator only between two single-character
        # operands (Appendix F.1.1); after a completed range, at the
        # edges, or before ']' it is LITERAL — and Ruby warns on the
        # literal. Escape the literals at the root.
        #
        # @return [String]
        def escape_hyphens(body)
          out = +""
          i = 0
          # :operand (a single-char operand just ended),
          # :range (a separator was just emitted, operand expected),
          # :range_done (a range just completed — the next '-' is a
          # literal), :open (nothing yet / non-operand before)
          state = :open
          while i < body.length
            ch = body[i]
            if ch == "\\"
              esc = escape_run(body, i)
              out << esc
              i += esc.length
              state = esc.match?(/\A\\[pP]\{/) ? :open : :operand
            elsif ch == "-"
              literal =
                state == :range_done || state == :open ||
                i.zero? || body[i + 1] == "]"
              out << (literal ? "\\-" : "-")
              state = literal ? :operand : :range
              i += 1
            else
              out << ch
              i += 1
              state = state == :range ? :range_done : :operand
            end
          end
          out
        end

        # The escape run starting at pos: property escapes span to their
        # closing brace, everything else is backslash + one char.
        #
        # @return [String]
        def escape_run(body, pos)
          rest = body[(pos + 1)..].to_s
          if rest.match?(/\A[pP]\{/) && (close = rest.index("}"))
            body[pos, close + 2]
          else
            body[pos, 2]
          end
        end

        # [X-[Y]] consumes one character that is in X and not in Y.
        def subtraction(base, subtracted)
          "(?>#{lookahead_in(base)}(?!#{class_body(subtracted)}).)"
        end

        def lookahead_in(body)
          "(?=[#{escape_hyphens(rewrite_escapes(body))}])"
        end

        def class_body(body)
          "[#{escape_hyphens(rewrite_escapes(body))}]"
        end

        def rewrite_escapes(body)
          body.gsub(/\\([pP])\{([^}]*)\}/) do
            "\\#{Regexp.last_match(1)}{#{block_name(Regexp.last_match(2))}}"
          end
            .gsub("\\i") { NAME_START_CLASS }
            .gsub("\\I") { NAME_START_COMPLEMENT }
            .gsub("\\c") { NAME_CHAR_CLASS }
            .gsub("\\C") { NAME_CHAR_COMPLEMENT }
            # Class-interior expansions: the categories PARTITION every
            # character, so complements become exact positive unions
            # (\w = not P/Z/C = L/M/N/S; \W = P/Z/C). \S stays Ruby's
            # (non-ASCII whitespace corners aside).
            .gsub("\\d") { "\\p{Nd}#{LEGACY_ND[1..]}" }
            .gsub("\\D") { "\\P{Nd}" }
            .gsub("\\w") { "\\p{L}\\p{M}\\p{N}\\p{S}" }
            .gsub("\\W") { "\\p{P}\\p{Z}\\p{C}" }
            .gsub("\\s") { "\\t\\n\\r " }
        end

        # XSD writes blocks as \p{IsBasicLatin} (hyphenated, camel-cased);
        # Ruby as \p{In_Basic_Latin} (underscore-separated). General
        # categories (L, Lu, Nd, ...) pass through unchanged.
        def block_name(xsd_name)
          return xsd_name unless xsd_name.start_with?("Is")

          stripped = xsd_name.delete_prefix("Is")
          return "In_#{BLOCK_RENAMES[stripped]}" if BLOCK_RENAMES.key?(stripped)

          words = stripped
            .gsub("-", "_")
            .gsub(/(?<=[A-Z])(?=[A-Z][a-z])/, "_")
            .gsub(/(?<=[a-z0-9])(?=[A-Z])/, "_")
            .split("_")
            .reject(&:empty?)
          "In_#{words.join('_')}"
        end
      end
    end
  end
end
