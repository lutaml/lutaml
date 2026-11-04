# frozen_string_literal: true

require "paint"

module Expressir
  module Commands
    class NonAsciiViolationCollection
      # Pre-defined mapping of common Unicode math symbols to AsciiMath.
      UNICODE_TO_ASCIIDOC_MAP = {
        # Greek letters
        "α" => "alpha", "β" => "beta", "γ" => "gamma", "Γ" => "Gamma",
        "δ" => "delta", "Δ" => "Delta", "ε" => "epsilon", "ζ" => "zeta",
        "η" => "eta", "θ" => "theta", "Θ" => "Theta", "ι" => "iota",
        "κ" => "kappa", "λ" => "lambda", "Λ" => "Lambda", "μ" => "mu",
        "ν" => "nu", "ξ" => "xi", "Ξ" => "Xi", "π" => "pi", "Π" => "Pi",
        "ρ" => "rho", "σ" => "sigma", "Σ" => "Sigma", "τ" => "tau",
        "υ" => "upsilon", "φ" => "phi", "Φ" => "Phi", "χ" => "chi",
        "ψ" => "psi", "Ψ" => "Psi", "ω" => "omega", "Ω" => "Omega",
        # Math operators
        "×" => "xx", "÷" => "div", "±" => "pm", "∓" => "mp",
        "∞" => "oo", "≤" => "le", "≥" => "ge", "≠" => "ne",
        "≈" => "~~", "≅" => "cong", "≡" => "equiv", "∈" => "in",
        "∉" => "notin", "⊂" => "subset", "⊃" => "supset", "∩" => "cap",
        "∪" => "cup", "∧" => "and", "∨" => "or", "¬" => "neg",
        "∀" => "forall", "∃" => "exists", "∄" => "nexists", "∇" => "grad",
        "∂" => "del", "∑" => "sum", "∏" => "prod", "∫" => "int",
        "∮" => "oint", "√" => "sqrt", "⊥" => "perp", "‖" => "norm",
        "→" => "rarr", "←" => "larr", "↔" => "harr",
        "⇒" => "rArr", "⇐" => "lArr", "⇔" => "hArr"
      }.freeze

      attr_reader :file_violations, :total_files

      def initialize(check_remarks: false)
        @file_violations = {} # Map of file paths to FileViolations objects
        @total_files = 0
        @unicode_to_asciimath = nil
        @check_remarks = check_remarks
      end

      def process_file(file)
        @total_files += 1

        # Initialize the mapping once
        @unicode_to_asciimath ||= UNICODE_TO_ASCIIDOC_MAP

        file_violations = process_file_violations(file)
        return if file_violations.violations.empty?

        @file_violations[file] = file_violations
      end

      def files_with_violations
        @file_violations.size
      end

      def total_violations
        @file_violations.values.sum(&:violation_count)
      end

      def unique_character_count
        # Get total unique characters across all files
        all_chars = Set.new
        @file_violations.each_value do |file_violation|
          file_violation.unique_characters.each do |char|
            all_chars.add(char.char)
          end
        end
        all_chars.size
      end

      def total_occurrence_count
        # Sum all occurrences of all characters across all files
        @file_violations.values.sum do |file_violation|
          file_violation.unique_characters.sum(&:occurrence_count)
        end
      end

      def to_yaml_data
        {
          summary: {
            total_files: @total_files,
            files_with_violations: files_with_violations,
            total_violations: total_violations,
            total_unique_characters: unique_character_count,
            total_occurrences: total_occurrence_count,
          },
          violations: @file_violations.transform_keys do |k|
            File.expand_path(k)
          end.transform_values(&:to_h),
        }
      end

      def print_text_output
        # Print each file's violations if any
        unless @file_violations.empty?
          @file_violations.each_value do |file_violation|
            puts "\n#{Paint[file_violation.display_path, :cyan, :bold]}:"

            file_violation.violations.each do |v|
              puts "  #{Paint['Line',
                              :blue]} #{Paint[v[:line_number],
                                              :yellow]}, #{Paint['Column',
                                                                 :blue]} #{Paint[v[:column],
                                                                                 :yellow]}:"
              puts "    #{v[:line]}"
              puts "    #{' ' * v[:column]}#{Paint['^' * v[:match].length,
                                                   :red]} #{Paint['Non-ASCII sequence',
                                                                  :red]}"

              v[:char_details].each do |cd|
                character = file_violation.unique_characters.find do |c|
                  c.char == cd[:char]
                end
                next unless character

                puts "      #{Paint["\"#{cd[:char]}\"",
                                    :yellow]} - Hex: #{Paint[cd[:hex],
                                                             :magenta]}, UTF-8 bytes: #{Paint[cd[:utf8],
                                                                                              :magenta]}"
                puts "      #{Paint['Replacement:',
                                    :green]} #{character.replacement_text}"
              end
              puts ""
            end

            puts "  #{Paint['Found',
                            :green]} #{Paint[file_violation.violation_count,
                                             :red]} #{Paint['non-ASCII sequence(s) in',
                                                            :green]} #{Paint[file_violation.filename,
                                                                             :cyan]}\n"
          end
        end

        # Always print summary
        validation_scope = @check_remarks ? "code and all remarks" : "code and tail remarks (embedded remarks excluded)"
        puts "\n#{Paint['Summary:', :blue, :bold]}"
        puts "  #{Paint['Validation scope:',
                        :green]} #{Paint[validation_scope,
                                         :cyan]}"
        puts "  #{Paint['Scanned',
                        :green]} #{Paint[@total_files,
                                         :yellow]} #{Paint['EXPRESS file(s)',
                                                           :green]}"
        puts "  #{Paint['Found',
                        :green]} #{Paint[total_violations,
                                         :red]} #{Paint['non-ASCII sequence(s) in',
                                                        :green]} #{Paint[files_with_violations,
                                                                         :red]} #{Paint['file(s)',
                                                                                        :green]}"
      end

      def print_table_output
        return if @file_violations.empty?

        # Build rows array
        rows = []
        total_occurrences = 0

        @file_violations.each_value do |file_violation|
          file_violation.unique_characters.each do |character|
            occurrence_count = character.occurrence_count
            total_occurrences += occurrence_count

            rows << {
              file: file_violation.display_path,
              symbol: "\"#{character.char}\" (#{character.hex})",
              replacement: character.replacement_text,
              occurrences: occurrence_count,
            }
          end
        end

        # Add total row
        rows << {
          file: "TOTAL",
          symbol: "#{unique_character_count} unique",
          replacement: "",
          occurrences: total_occurrences,
        }

        # Use TableTennis to render
        options = {
          title: "Non-ASCII Characters Summary",
          columns: %i[file symbol replacement occurrences],
          headers: {
            file: "File",
            symbol: "Symbol",
            replacement: "Replacement",
            occurrences: "Occurrences",
          },
          mark: ->(row) { row[:file] == "TOTAL" },
        }

        puts "\n#{TableTennis.new(rows, options)}\n"
      end

      private

      # Build a masked copy of `source` where every byte inside an embedded
      # remark region is replaced with an ASCII space. Byte positions and the
      # string's encoding are preserved, so masked lines still align 1:1 with
      # the original file for reporting.
      def mask_embedded_remarks(source)
        remarks = Expressir::Express::RemarkScanner.new(source).scan
        embedded = remarks.select(&:embedded?)
        return source if embedded.empty?

        masked = source.b.dup
        embedded.each do |r|
          (r.position...r.end_position).each { |i| masked.setbyte(i, 0x20) }
        end
        masked.force_encoding(source.encoding)
      end

      def scan_lines_for_non_ascii(file_violations, lines)
        lines.each_with_index do |line, line_idx|
          line_number = line_idx + 1
          next unless /[^\x00-\x7F]/.match?(line)

          line.chomp.scan(/([^\x00-\x7F]+)/) do |match|
            match = match[0]
            column = line.index(match)

            char_details = match.chars.filter_map do |c|
              process_non_ascii_char(c)
            end
            next if char_details.empty?

            file_violations.add_violation(line_number, column, match,
                                          char_details, line.chomp)
          end
        end
      end

      def process_file_violations(file)
        file_violations = FileViolations.new(file)
        source = File.read(file, encoding: "UTF-8")

        # With --check-remarks: scan every line including embedded remarks.
        # Without: scan code + tail remarks only — mask out embedded remark
        # regions so non-ASCII inside `(* ... *)` documentation blocks is
        # not flagged. Tail remarks (`--`) are part of code lines and stay
        # in scope (issue #285).
        scan_source = @check_remarks ? source : mask_embedded_remarks(source)
        scan_lines_for_non_ascii(file_violations, scan_source.lines)
        file_violations
      end

      def process_non_ascii_char(char)
        # Skip ASCII characters
        return nil if char.ord <= 0x7F

        code_point = char.ord
        hex = "0x#{code_point.to_s(16)}"
        utf8 = code_point.chr(Encoding::UTF_8).bytes.map do |b|
          "0x#{b.to_s(16)}"
        end.join(" ")

        # Check if it's a math symbol
        if asciimath = @unicode_to_asciimath[char]
          return {
            char: char,
            hex: hex,
            utf8: utf8,
            is_math: true,
            replacement: asciimath,
            replacement_type: "asciimath",
          }
        end

        # Not a math symbol, use ISO encoding
        {
          char: char,
          hex: hex,
          utf8: utf8,
          is_math: false,
          replacement: encode_express_format(char),
          replacement_type: "iso-10303-11",
        }
      end

      def encode_express_format(char)
        code_point = char.ord

        # Format the encoded value with double quotes
        if code_point < 0x10000
          "\"#{sprintf('%08X', code_point)}\"" # e.g., "00000041" for 'A'
        else
          # For higher code points, use all four octets
          group = (code_point >> 24) & 0xFF
          plane = (code_point >> 16) & 0xFF
          row = (code_point >> 8) & 0xFF
          cell = code_point & 0xFF

          "\"#{sprintf('%02X%02X%02X%02X', group, plane, row, cell)}\""
        end
      end
    end
  end
end
