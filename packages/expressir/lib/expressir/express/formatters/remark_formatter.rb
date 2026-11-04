module Expressir
  module Express
    module Formatters
      module RemarkFormatter
        def format_remark(node, remark)
          # Handle embedded remarks
          if remark.include?("\n")
            [
              [
                "(*\"",
                node.path || node.id,
                "\"",
              ].join,
              remark,
              "*)",
            ].join("\n")
          elsif node.path.nil? && node.id.include?("IP")
            # Handle immediate informal propositions
            [
              "--",
              node.id,
              " ",
              remark,
            ].join
          else
            # Handle tail remarks
            [
              "--\"",
              node.path || node.id,
              "\" ",
              remark,
            ].join
          end
        end

        def format_untagged_remark(remark)
          return "" unless remark.is_a?(Model::RemarkInfo)

          text = remark.text
          return "" if text.nil? || text.empty?

          formatted_text = remark.tagged? ? "\"#{remark.tag}\" #{text}" : text

          if remark.tail?
            "-- #{formatted_text}"
          elsif text.include?("\n")
            ["(*", formatted_text, "*)"].join("\n")
          else
            "(* #{formatted_text} *)"
          end
        end

        def format_inline_tail_remark(node)
          return "" if @no_remarks
          return "" unless node.is_a?(Model::ModelElement)
          return "" if node.untagged_remarks.nil? || node.untagged_remarks.empty?

          remark = node.untagged_remarks.first
          return "" unless remark.is_a?(Model::RemarkInfo)

          text = remark.text
          return "" if text.nil? || text.empty?

          formatted_text = remark.tagged? ? "\"#{remark.tag}\" #{text}" : text
          remark.tail? ? " -- #{formatted_text}" : " (* #{formatted_text} *)"
        end

        def format_end_scope_remark(node)
          return "" if @no_remarks
          return "" unless node.is_a?(Model::ModelElement)

          # Only legacy (unplaced) remarks belong after the END_* keyword.
          # Remarks carrying an explicit placement are rendered by the
          # placement-aware emitters, and must not be emitted twice.
          remark = Array(node.untagged_remarks).reject(&:placement).last
          return "" unless remark.is_a?(Model::RemarkInfo)

          text = remark.text
          return "" if text.nil? || text.empty?

          # Only output if it's a tail remark (END_* scope remarks are always tail)
          return "" unless remark.tail?

          formatted_text = remark.tagged? ? "\"#{remark.tag}\" #{text}" : text
          " -- #{formatted_text}"
        end

        def format_preamble_remark(remark, indent_str = "")
          return "" unless remark.is_a?(Model::RemarkInfo)

          text = remark.text
          text = "\"#{remark.tag}\" #{text}" if remark.tagged?

          if remark.tail?
            "#{indent_str}-- #{text}"
          elsif text.include?("\n")
            lines = text.split("\n")
            [
              "#{indent_str}(*",
              *lines.map { |line| "#{indent_str}  #{line.strip}" },
              "#{indent_str}*)",
            ].join("\n")
          else
            "#{indent_str}(* #{text} *)"
          end
        end

        def format_preamble_remarks(node, indent_str = "")
          return nil if @no_remarks
          return nil unless node.is_a?(Model::ModelElement)
          return nil if node.untagged_remarks.nil? || node.untagged_remarks.empty?

          # For scope containers, exclude the last tail remark as it's the END_* remark
          # but keep all embedded remarks
          is_scope_container = node.is_a?(Model::Declarations::Schema) ||
            node.is_a?(Model::Declarations::Entity) ||
            node.is_a?(Model::Declarations::Type) ||
            node.is_a?(Model::Declarations::Function) ||
            node.is_a?(Model::Declarations::Procedure) ||
            node.is_a?(Model::Declarations::Rule)

          preamble_remarks = node.untagged_remarks.select do |remark|
            remark.is_a?(Model::RemarkInfo) && !remark.text.nil? && !remark.text.empty?
          end

          # For scope containers: exclude last remark ONLY if it's a tail remark (END_* remark)
          # Keep all embedded remarks
          if is_scope_container && preamble_remarks.length >= 1
            last_remark = preamble_remarks.last
            # Only exclude if it's a tail remark
            preamble_remarks = preamble_remarks[0..-2] if last_remark.tail?
          end

          return nil if preamble_remarks.empty?

          preamble_remarks.map do |remark|
            format_preamble_remark(remark, indent_str)
          end.join("\n")
        end

        # Remarks that close one body of `node`, emitted just before that
        # body's closing keyword. Only explicit TRAILING remarks for the named
        # region qualify: legacy (nil) remarks keep their historical emission
        # path so old caches render exactly as they did before.
        def format_trailing_region_remarks(node, region)
          return [] if @no_remarks
          return [] unless node.is_a?(Model::ModelElement)

          Array(node.untagged_remarks).filter_map do |remark|
            next unless remark.trailing_region?(region)

            formatted = format_untagged_remark(remark)
            formatted unless formatted.empty?
          end
        end

        # Remarks written after their statement on the same line, which for a
        # single-line statement is where appending puts them back. Opener
        # remarks are excluded: those belong on the first line rather than
        # after the closing keyword, and {#format_opener_remarks} emits them.
        # Mid-keyword remarks (ELSE / OTHERWISE regions) are excluded too:
        # {#format_mid_keyword_remarks} emits them after their keyword.
        def format_inline_statement_remarks(node)
          formatted_inline_remarks(node) { |remark| remark.region.nil? }
        end

        # Remarks that trailed the opening line of a statement spanning
        # several lines, as in `IF x THEN -- why`. Where they are written back
        # is Formatter#format's business, not this method's.
        def format_opener_remarks(node)
          formatted_inline_remarks(node, &:opener?)
        end

        # Remarks that trailed a mid-construct keyword of `node` — the ELSE
        # line of an IF, the OTHERWISE line of a CASE — emitted after that
        # keyword, where they were written.
        def format_mid_keyword_remarks(node, region)
          formatted_inline_remarks(node) { |remark| remark.inline_region?(region) }
        end

        # The inline remarks of a node that the given block accepts, formatted
        # and joined. The callers partition the same collection, so every
        # inline remark is emitted by exactly one of them.
        def formatted_inline_remarks(node, &)
          return "" if @no_remarks
          return "" unless node.is_a?(Model::TakesInlineRemark)

          Array(node.untagged_remarks).filter_map do |remark|
            next unless remark.inline? && yield(remark)

            formatted = format_untagged_remark(remark)
            formatted unless formatted.empty?
          end.map { |text| " #{text}" }.join
        end

        def format_leading_statement_remarks(node)
          return [] if @no_remarks
          return [] unless node.is_a?(Model::Statement)

          Array(node.untagged_remarks).filter_map do |remark|
            next unless remark.leading?

            formatted = format_untagged_remark(remark)
            formatted unless formatted.empty?
          end
        end

        # Block-end emission for ALIAS/REPEAT bodies. Tagged remarks are
        # stored as bare text in node.remarks alongside a mirror of every
        # untagged text (add_remark dual-store), so "genuinely tagged" is
        # derivable only by multiset-subtracting the untagged texts.
        def format_block_end_remarks(node)
          return [] if @no_remarks

          untagged = Array(node.untagged_remarks)
          remaining = untagged.map(&:text).tally
          tagged = Array(node.remarks).compact.reject do |text|
            next false unless remaining[text]&.positive?

            remaining[text] -= 1
            true
          end

          [
            *tagged.map { |text| format_remark(node, text) },
            # Leading and inline remarks are emitted by their own paths;
            # including them here would render them a second time.
            *untagged.reject { |r| r.leading? || r.inline? }
              .filter_map do |remark|
                formatted = format_untagged_remark(remark)
                formatted unless formatted.empty?
              end,
          ]
        end

        def format_remarks(node)
          remarks = []

          # Add tagged remarks
          if node.is_a?(Model::HasRemarks) && !@no_remarks &&
              !node.remarks.nil?
            remarks.concat(node.remarks.compact.map do |remark|
              format_remark(node, remark)
            end)
          end

          # Skip untagged remarks for nodes that handle them separately
          skip_untagged = node.is_a?(Model::Declarations::Attribute) ||
            node.is_a?(Model::DataTypes::EnumerationItem) ||
            node.is_a?(Model::Declarations::Schema) ||
            node.is_a?(Model::Declarations::Entity) ||
            node.is_a?(Model::Declarations::Type) ||
            node.is_a?(Model::Declarations::Function) ||
            node.is_a?(Model::Declarations::Procedure) ||
            node.is_a?(Model::Declarations::Rule)

          # Add untagged remarks only for nodes that don't handle them specially
          if !skip_untagged && node.is_a?(Model::ModelElement) && !@no_remarks &&
              !node.untagged_remarks.nil?
            remarks.concat(node.untagged_remarks.map do |remark|
              format_untagged_remark(remark)
            end)
          end

          remarks
        end
      end
    end
  end
end
