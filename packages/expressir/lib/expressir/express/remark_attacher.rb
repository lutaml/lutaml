# frozen_string_literal: true

module Expressir
  module Express
    # Handles attaching remarks (comments) to model elements after parsing.
    #
    # Two collaborators sit behind the `attach` interface:
    # - {ScopeResolver} answers "which scope contains line N?"
    # - {NodePositionIndex} answers "which model node is nearest line N?"
    #
    # Remark scanning itself lives in {RemarkScanner}; line→byte lookup lives
    # in {LineMap}. This class is the orchestrator: it walks the remarks, asks
    # the collaborators for targets, and writes the remarks onto the model.
    #
    # NOTE: Post-processing remark attachment has inherent limitations for scope-based
    # matching. Remarks with simple tags (like "WR1") inside scopes (TYPE, ENTITY, etc.)
    # cannot be perfectly matched without parsing context. This implementation prioritizes:
    # 1. Exact path matches (e.g., "schema.entity.WR1")
    # 2. Proximity-based matching for simple tags
    # 3. NOT creating spurious schema-level items for ambiguous tags
    class RemarkAttacher
      # Type-driven registry: maps each model class to its collection attributes.
      # Shared with {NodePositionIndex} via that class's own copy of the table.
      # Two declarations rather than a cross-reference so each module is loadable
      # on its own without forcing the other to load.
      COLLECTION_REGISTRY = NodePositionIndex::COLLECTION_REGISTRY

      # Collections holding executable statements — the regions a body
      # comment can belong to.
      STATEMENT_REGIONS = %i[
        statements else_statements action_statements otherwise_statements
      ].freeze

      # Expression and statement child attributes are declared on the model
      # via `child_attributes :foo, :bar, ...`. See TODO.bugs/15.
      EXPRESSION_CHILDREN = Model::ModelElement.child_attributes_registry

      # `WHERE <label> :` clause headers; the captured label maps to the
      # 1-based line number(s) it appears on.
      WHERE_CLAUSE_PATTERN = /\A\s*WHERE\s+(\w+)\s*:/i

      def initialize(source)
        @source = source
        @attached_spans = Set.new
        @line_map = LineMap.new(source.b)
        @model = nil
        @scope_resolver = nil
        @node_index = nil
        @owner_map = nil
        @active_scope_map = nil
      end

      def attach(model)
        @model = model
        remarks = RemarkScanner.new(@source).scan

        @node_index = NodePositionIndex.new(model, @line_map)
        @scope_resolver = ScopeResolver.new(
          source: @source,
          model: model,
          nodes_with_positions: @node_index.nodes,
        )

        attach_tagged_remarks(remarks)
        attach_untagged_remarks(remarks)

        model
      ensure
        # Free expensive data structures once attachment is over. On the
        # raising path this also drops the memoized ownership map, which
        # would otherwise outlive the node index it was derived from.
        @source = nil
        @scope_resolver = nil
        @node_index = nil
        @line_map = nil
        @owner_map = nil
        @active_scope_map = nil
        @source_lines_for_where_clause = nil
        @where_clause_line_index = nil
      end

      private

      # ----- Tagged remark attachment -----

      def attach_tagged_remarks(remarks)
        tagged = remarks.select(&:tag)
        return if tagged.empty?

        tagged.each do |remark|
          next if @attached_spans.include?(remark.position)

          tag = remark.tag
          target = nil

          containing_scope = @scope_resolver.containing_scope_for(remark.line)

          # Check if this is an informal proposition tag (IP\d+)
          if tag.match?(/^IP\d+$/)
            scope = containing_scope || @scope_resolver.find_by_source_text(remark.line)
            if scope && supports_informal_propositions?(scope)
              target = create_or_find_informal_proposition(scope, tag)
            end
          end

          # Standard path-based lookup
          if target.nil?
            # Handle prefixed tags like wr:WR1, ip:IP1, ur:UR1
            if tag.include?(":") && !tag.include?(".")
              target = handle_prefixed_tag(tag, containing_scope, @model,
                                           get_schema_ids(@model))
            end

            # Strategy 1: Try exact path lookup
            if target.nil?
              target = find_by_exact_path(@model, tag)
            end

            # Strategy 1b: For paths with dots, try with scope path prefix first
            if target.nil? && tag.include?(".")
              if containing_scope && function_rule_procedure?(containing_scope)
                scope_path = build_scope_path(containing_scope)
                if scope_path
                  target = find_by_exact_path(@model, "#{scope_path}.#{tag}")
                end
              end

              if target.nil?
                schema_ids = get_schema_ids(@model)
                schema_ids.each do |schema_id|
                  target = find_by_exact_path(@model, "#{schema_id}.#{tag}")
                  break if target
                end
              end
            end

            # Strategy 2: For simple tags, find in containing scope first
            if target.nil? && !tag.include?(".")
              if containing_scope
                target = find_node_in_scope(containing_scope, tag)

                if target.nil? && supports_where_rules?(containing_scope)
                  target = find_target_in_where_clause(containing_scope, tag,
                                                       remark.line)
                end

                if target.nil? && !function_rule_procedure?(containing_scope)
                  schema_ids = get_schema_ids(@model)
                  schema_ids.each do |schema_id|
                    target = find_by_exact_path(@model, "#{schema_id}.#{tag}")
                    break if target
                  end
                end
              else
                schema_ids = get_schema_ids(@model)
                schema_ids.each do |schema_id|
                  target = find_by_exact_path(@model, "#{schema_id}.#{tag}")
                  break if target
                end
              end
            end

            # Strategy 3: Create implicit item for qualified paths only
            if target.nil? && tag.include?(".")
              if containing_scope && function_rule_procedure?(containing_scope)
                scope_path = build_scope_path(containing_scope)
                if scope_path
                  target = create_implicit_remark_item(@model, "#{scope_path}.#{tag}",
                                                       get_schema_ids(@model))
                end
              end
              if target.nil?
                target = create_implicit_remark_item(@model, tag,
                                                     get_schema_ids(@model))
              end
            end

            # Strategy 4: For simple tags at schema level, create implicit item
            if target.nil? && !tag.include?(".")
              schema_ids = get_schema_ids(@model)
              if schema_ids.any?
                target = create_implicit_remark_item_at_schema(@model, tag,
                                                               schema_ids.first)
              end
            end
          end

          if target
            add_remark(target, remark.text, format: remark.format, tag: remark.tag,
                                            source_offset: remark.position)
            @attached_spans << remark.position
          end
        end
      end

      # ----- Untagged remark attachment -----

      def attach_untagged_remarks(remarks)
        untagged = remarks.reject(&:tag)
        return unless untagged.any?

        untagged.each do |remark|
          next if @attached_spans.include?(remark.position)

          line_content = line_content_for(remark.line)
          if end_scope_line?(line_content)
            matched_node = @node_index.node_for_end_scope_at(remark.line, line_content)
            if matched_node
              add_remark(matched_node, remark.text, format: remark.format, tag: nil,
                                                    source_offset: remark.position)
              @attached_spans << remark.position
              next
            end
          end

          target, placement, region = find_body_comment_target(remark)
          if target
            add_remark(target, remark.text, format: remark.format, tag: nil,
                                            placement: placement, region: region)
            @attached_spans << remark.position
            next
          end

          matched_node = @node_index.nearest_node_to(remark.line)
          if matched_node
            add_remark(matched_node, remark.text, format: remark.format, tag: nil,
                                                  source_offset: remark.position)
            @attached_spans << remark.position
          end
        end
      end

      def end_scope_line?(line_content)
        line_content =~ /END_(SCHEMA|ENTITY|TYPE|FUNCTION|PROCEDURE|RULE)/i
      end

      # Own-line body comments belong to the next statement in the same
      # statement region (Function body, THEN branch, ELSE branch, loop body):
      # attached there with LEADING placement. A comment with no following
      # statement in its region closes that region, so it attaches to the
      # region's owner with TRAILING placement and the region's name — an IF
      # owns two bodies that close at different keywords.
      #
      # Returns [nil, nil, nil] — "use the legacy fallback" — when the remark
      # shares a line with a node or sits outside any statement-bearing node.
      def find_body_comment_target(remark)
        line = remark.line
        # An own-line comment shares its line with no node. A node STARTING
        # here means the remark is an inline tail (code; -- note). The
        # end-line check is restricted to statements: container end_lines are
        # child-derived approximations that can collide with comment lines.
        if inline_remark?(remark)
          target, placement, region = inline_target(remark,
                                                    @node_index.starting_at(line))
          return [target, placement, region] if target

          # A remark trailing a mid-construct keyword (`ELSE -- why`) starts
          # nothing and closes nothing; handled before the legacy fallthrough,
          # which would hand it to the enclosing construct unplaced — where
          # nothing renders it.
          mid = mid_keyword_inline_target(remark)
          return mid if mid
        end

        # A closing keyword on the next code line is decisive: the comment
        # closes that body. Without this check the comment would instead be
        # read as leading the next statement of an OUTER region, which is
        # where it would wrongly render.
        closing = closing_region_target(line)
        return closing if closing.first

        enclosing, region, = statement_region_for(line)
        return [nil, nil, nil] unless region

        following = region
          .select { |n| n[:line] > line }
          .min_by { |n| n[:position] }
        if following
          return [following[:node], Model::RemarkPlacement::LEADING, nil]
        end

        # No following statement and no closing keyword above: the comment is
        # not demonstrably inside this body (it may sit after the whole
        # declaration). Keep the legacy attachment rather than guessing.
        [enclosing[:node], nil, nil]
      end

      # Whether the remark trails code on its own line. Decided from the
      # source text before it, not from node positions: container end lines
      # are child-derived approximations that collide with comment lines and
      # would misread an own-line comment as a trailing one.
      def inline_remark?(remark)
        content = line_content_for(remark.line).to_s
        opener = content.index("--")
        return false unless opener

        !content[0...opener].strip.empty?
      end

      # A comment trailing code on its line belongs to the statement it
      # follows: `x := 1; -- why`, or the opener of a compound one, as in
      # `IF x THEN -- why`.
      #
      # Multi-line statements were once excluded here, because appending a
      # remark to one would carry it down to its closing keyword. They are
      # admitted now that the formatter can put an opener remark back on the
      # first line; the OPENER_REGION on the returned placement is what tells
      # it to, and without that region the old appending behaviour stands.
      def inline_target(remark, nodes)
        started_here = nodes.select do |n|
          n[:node].is_a?(Model::TakesInlineRemark) &&
            n[:line] == remark.line &&
            n[:position] && n[:position] < remark.position
        end

        # Of the two that began here, whichever starts later is the one the
        # remark follows: `x := 0; IF n > 0 THEN -- why` trails the IF.
        began = [single_line_owner(started_here, remark.line),
                 opener_owner(started_here, remark.line)]
          .compact.max_by { |n| n[:position] }

        owner = began || closing_owner(nodes, remark)
        return [nil, nil, nil] unless owner

        [owner[:node], Model::RemarkPlacement::INLINE,
         opener_region(owner, remark.line)]
      end

      # A node beginning and ending on the remark's line. Ranked by where it
      # ends, so of several sharing the line the outermost complete one wins:
      # `CASE n OF 1 : x := 2; END_CASE; -- why` trails the CASE, not its
      # action.
      def single_line_owner(candidates, line)
        candidates
          .select { |n| n[:end_line] == line }
          .max_by { |n| n[:position] + n[:node].source.to_s.length }
      end

      # A node whose opener is on the remark's line but which continues past
      # it. Ranked by where it STARTS, not where it ends: such a node's source
      # spans its whole body, so ranking by end would let an enclosing block
      # outrank the one the remark actually follows.
      def opener_owner(candidates, line)
        candidates
          .select { |n| n[:end_line] && n[:end_line] > line }
          .max_by { |n| n[:position] }
      end

      # Nothing began on the remark's line, so it may still be closing one
      # that began earlier:
      #
      #     REFERENCE FROM x
      #       (a, b); -- why
      #
      # Only reached as a fallback. Were it folded into the main lookup, an
      # enclosing block would become a candidate for every remark inside it,
      # since a node's end line is derived from its children.
      def closing_owner(nodes, remark)
        nodes
          .select do |n|
            n[:node].is_a?(Model::TakesInlineRemark) &&
              n[:end_line] == remark.line && n[:line] &&
              n[:line] < remark.line &&
              n[:position] && n[:position] < remark.position
          end
          .max_by { |n| n[:position] }
      end

      # A remark trailing a node that closes on its line follows the whole
      # node, so it is written back the way an ordinary inline remark is. One
      # that continues past the line trailed the node's opener instead, and
      # belongs back there rather than after the closing keyword.
      def opener_region(owner, line)
        return nil unless owner[:end_line] && owner[:end_line] > line

        Model::RemarkPlacement::OPENER_REGION
      end

      # Lines beginning with a mid-construct keyword. The keyword closes
      # nothing and opens nothing, but the remark trailing it belongs to the
      # construct it branches — written back after the keyword, not after the
      # construct's END_.
      MID_KEYWORD_REGIONS = {
        /\AELSE\b/i => [Model::Statements::If,
                        Model::RemarkPlacement::ELSE_REGION],
        /\AOTHERWISE\b/i => [Model::Statements::Case,
                             Model::RemarkPlacement::OTHERWISE_REGION],
      }.freeze

      # Attach `ELSE -- why` / `OTHERWISE : -- why` to the innermost
      # enclosing IF / CASE with INLINE placement and the keyword's region.
      # Returns [nil, nil, nil] when the line head is no mid-construct
      # keyword or no construct of the right kind spans the line.
      def mid_keyword_inline_target(remark)
        content = line_content_for(remark.line).to_s
        opener = content.index("--")
        return [nil, nil, nil] unless opener

        owner = MID_KEYWORD_REGIONS.find { |pattern, _| content[0...opener].strip.match?(pattern) }
        return [nil, nil, nil] unless owner

        klass, region = owner[1]
        innermost = @node_index.nodes.select do |n|
          n[:node].is_a?(klass) && n[:line] && n[:end_line] &&
            n[:line] < remark.line && n[:end_line] > remark.line
        end.max_by { |n| n[:line] }
        return [nil, nil, nil] unless innermost

        [innermost[:node], Model::RemarkPlacement::INLINE, region]
      end

      # Which closing keyword ends which region of which owner. A comment
      # sitting between a body's last statement and one of these keywords
      # closes that body.
      CLOSING_KEYWORDS = {
        /\AELSE\b/i => [Model::Statements::If, :statements],
        /\AEND_IF\b/i => [Model::Statements::If, :else_statements],
        /\AOTHERWISE\b/i => [Model::Statements::Case, :action_statements],
        /\AEND_CASE\b/i => [Model::Statements::Case, :otherwise_statements],
        /\AEND_REPEAT\b/i => [Model::Statements::Repeat, :statements],
        /\AEND_ALIAS\b/i => [Model::Statements::Alias, :statements],
        /\AEND\s*;/i => [Model::Statements::Compound, :statements],
        # A RULE's executable body ends at WHERE, not at END_RULE.
        /\AWHERE\b/i => [Model::Declarations::Rule, :statements],
        /\AEND_FUNCTION\b/i => [Model::Declarations::Function, :statements],
        /\AEND_PROCEDURE\b/i => [Model::Declarations::Procedure, :statements],
        # END_RULE closes the WHERE section when the rule has one.
        /\AEND_RULE\b/i => [Model::Declarations::Rule, :where_rules],
      }.freeze

      # Regions whose owner may not have that body, in which case the
      # keyword closes the earlier region instead.
      REGION_FALLBACKS = {
        [Model::Statements::If, :else_statements] =>
          [:statements, ->(n) { n.else_statements&.length&.positive? }],
        [Model::Statements::Case, :otherwise_statements] =>
          [:action_statements, ->(n) { !n.otherwise_statement.nil? }],
        [Model::Declarations::Rule, :where_rules] =>
          [:statements, ->(n) { n.where_rules&.length&.positive? }],
      }.freeze

      # A node's indexed span stops at its last child, so a comment written
      # after that child but before the node's closing keyword sits outside
      # every span and never reaches statement_region_for. Resolve it from
      # the keyword that follows: it names both the owner type and the body
      # being closed.
      def closing_region_target(line)
        keyword_owner, region, keyword_line = closing_keyword_after(line)
        return [nil, nil, nil] unless keyword_owner

        # The owner is the construct the keyword actually closes — the
        # innermost one still open at that line. Picking the latest node of
        # the right class instead would grab an already-closed inner block
        # (nested IFs) or an unrelated earlier declaration (a RULE, when the
        # WHERE really belongs to an ENTITY).
        opener_line = active_opener_line(keyword_line, keyword_owner)
        return [nil, nil, nil] unless opener_line

        owner = @node_index.starting_at(opener_line).find do |n|
          n[:node].is_a?(keyword_owner)
        end
        return [nil, nil, nil] unless owner

        # END_IF closes the THEN body when there is no ELSE; END_CASE closes
        # the last action when there is no OTHERWISE.
        fallback, present = REGION_FALLBACKS[[keyword_owner, region]]
        region = fallback if fallback && !present.call(owner[:node])

        [owner[:node], Model::RemarkPlacement::TRAILING, region.to_s]
      end

      # The first non-blank, non-comment source line after `line`.
      # Source keywords that open a nestable construct, paired with the class
      # of node they produce. Used to find which construct a closing keyword
      # actually belongs to.
      OPENERS = [
        [/\bIF\b.*?\bTHEN\b/i, Model::Statements::If],
        [/\bCASE\b.*?\bOF\b/i, Model::Statements::Case],
        [/\bREPEAT\b/i, Model::Statements::Repeat],
        [/\bALIAS\b/i, Model::Statements::Alias],
        [/\bBEGIN\b/i, Model::Statements::Compound],
        [/\A\s*FUNCTION\b/i, Model::Declarations::Function],
        [/\A\s*PROCEDURE\b/i, Model::Declarations::Procedure],
        [/\A\s*RULE\b/i, Model::Declarations::Rule],
        [/\A\s*ENTITY\b/i, :other],
        [/\A\s*TYPE\b/i, :other],
      ].freeze

      CLOSERS = /\bEND_IF\b|\bEND_CASE\b|\bEND_REPEAT\b|\bEND_ALIAS\b|\bEND_FUNCTION\b|\bEND_PROCEDURE\b|\bEND_RULE\b|\bEND_ENTITY\b|\bEND_TYPE\b|\bEND\s*;/i

      # Strips what must not be scanned for keywords: string literals and a
      # trailing `--` remark. Without this, `x := 'IF a THEN'` or a comment
      # mentioning REPEAT would push a construct that never opened.
      def keyword_scannable(content)
        without_strings = content.gsub(/'[^']*'/, "''")
        tail = without_strings.index("--")
        tail ? without_strings[0...tail] : without_strings
      end

      # The opening line of the innermost construct still open at
      # `keyword_line`, or nil when that construct is not of `expected_class`.
      def active_opener_line(keyword_line, expected_class)
        active = active_scope_map[keyword_line]
        return nil unless active && active[0] == expected_class

        active[1]
      end

      # Line number => the construct open at the START of that line, as
      # [class, opening_line]. Built once per source: rescanning from line 1
      # for every trailing comment is quadratic, and on a comment-dense file
      # that cost dominates parsing entirely.
      def active_scope_map
        @active_scope_map ||= build_active_scope_map
      end

      def build_active_scope_map
        map = {}
        stack = []
        (1..source_line_count).each do |ln|
          map[ln] = stack.last
          content = keyword_scannable(line_content_for(ln).to_s.strip)
          next if content.empty? || content.start_with?("--")

          line_events(content).each do |_offset, kind, klass|
            kind == :open ? stack << [klass, ln] : stack.pop
          end
        end
        map
      end

      # Opener/closer events on one line, ordered by where they appear.
      # EVERY occurrence is collected, not just the first: a line holding two
      # complete IF blocks contributes two openers and two closers, and
      # recording only one opener would over-pop the enclosing construct.
      def line_events(content)
        events = []
        OPENERS.each do |pattern, klass|
          content.enum_for(:scan, pattern).each do
            events << [Regexp.last_match.begin(0), :open, klass]
          end
        end
        content.enum_for(:scan, CLOSERS).each do
          events << [Regexp.last_match.begin(0), :close, nil]
        end
        events.sort_by(&:first)
      end

      def closing_keyword_after(line)
        probe = line + 1
        # Skip further comment lines AND blank lines: a comment separated
        # from its closing keyword by an empty line still closes that body.
        while probe <= source_line_count
          content = line_content_for(probe).to_s.strip
          break unless content.empty? || content.start_with?("--")

          probe += 1
        end
        content = line_content_for(probe).to_s.strip
        CLOSING_KEYWORDS.each do |pattern, owner_region|
          return [*owner_region, probe] if content.match?(pattern)
        end
        [nil, nil, nil]
      end

      def statement_region_for(line, nodes = nil)
        candidates = (nodes || @node_index.spanning(line)).select do |n|
          n[:line] && n[:end_line] && n[:line] <= line && n[:end_line] >= line &&
            (n[:node].is_a?(Model::Statement) || function_rule_procedure?(n[:node]))
        end
        enclosing = innermost_candidate(candidates)
        return [nil, nil, nil] unless enclosing

        children = @node_index.children_in(enclosing[:node], STATEMENT_REGIONS)
        return [enclosing, nil, nil] if children.empty?

        preceding = children.select { |n| n[:line] < line }.max_by { |n| n[:position] }
        following = children.select { |n| n[:line] > line }.min_by { |n| n[:position] }
        region_attr = region_attr_for(line, preceding, following)
        return [enclosing, nil, nil] unless region_attr

        [enclosing, children.select { |n| n[:collection] == region_attr }, region_attr]
      end

      # Node end lines are child-derived approximations, so a parent's span
      # can come out SMALLER than a child's and span size alone picks the
      # wrong container. Ownership links are exact: drop every candidate
      # that is an ancestor of another candidate, then pick the smallest
      # span among the true leaves.
      def innermost_candidate(candidates)
        return candidates.first if candidates.length <= 1

        owner_of = owner_map
        ancestors = Set.new.compare_by_identity
        candidates.each do |cand|
          current = owner_of[cand[:node]]
          while current
            ancestors << current
            current = owner_of[current]
          end
        end

        leaves = candidates.reject { |n| ancestors.include?(n[:node]) }
        (leaves.empty? ? candidates : leaves).min_by { |n| n[:end_line] - n[:line] }
      end

      # The node index is immutable during attachment, so its ownership map
      # only needs to be built once for all body remarks.
      def owner_map
        # Identity comparison must be enabled BEFORE the hash is populated.
        # Model elements compare by value, so two distinct-but-equal nodes
        # would collapse into one entry during a plain build, and switching
        # to identity afterwards cannot recover the lost entry.
        @owner_map ||= @node_index.nodes.each_with_object(
          {}.compare_by_identity,
        ) { |n, map| map[n[:node]] = n[:owner] }
      end

      # The keyword that opens each region, for regions that follow another
      # region of the same owner. A comment in the gap belongs to whichever
      # side of this keyword it was written on.
      REGION_OPENERS = {
        else_statements: /\A(?:.*;)?\s*ELSE(?:\s*--.*)?\z/i,
        otherwise_statements: /\A\s*OTHERWISE\b/i,
      }.freeze

      # A comment between two regions of the same owner — between the THEN
      # body and ELSE, or between the last CASE action and OTHERWISE — sits
      # on one side of the keyword that opens the second region. The gap can
      # hold only that keyword and comments, so scanning it is exact.
      # Comment lines are skipped so prose mentioning the keyword cannot
      # match.
      def region_attr_for(line, preceding, following)
        return following&.dig(:collection) unless preceding

        following_attr = following&.dig(:collection)
        opener = REGION_OPENERS[following_attr]
        if opener && following_attr != preceding[:collection]
          opener_line = (preceding[:end_line]...following[:line]).find do |ln|
            content = line_content_for(ln).strip
            !content.start_with?("--") && opener.match?(content)
          end
          return following_attr if opener_line && line > opener_line
        end

        preceding[:collection]
      end

      # ----- Tag resolution (within a scope) -----

      def find_node_in_scope(scope, tag)
        return nil unless scope

        collections_on(scope).each do |collection|
          collection.each do |item|
            next unless item.is_a?(Model::HasRemarks)
            return item if item.id == tag
          end
        end

        types = get_collection(scope, :types)
        types&.each do |type|
          result = find_enumeration_item_in_type(type, tag)
          return result if result
        end

        statements = get_collection(scope, :statements)
        statements&.each do |stmt|
          result = find_node_in_statement(stmt, tag)
          return result if result

          result = find_query_in_expression(stmt, tag)
          return result if result
        end

        nil
      end

      def find_enumeration_item_in_type(type, tag)
        return nil unless type
        return nil unless type.is_a?(Model::Declarations::Type)

        type.enumeration_items&.each do |item|
          return item if item.id == tag
        end

        ut = type.underlying_type
        return nil unless ut.is_a?(Model::DataTypes::Enumeration) && ut.items

        ut.items.each { |item| return item if item.id == tag }
        nil
      end

      def find_query_in_expression(node, tag, visited = Set.new)
        return nil unless node
        return nil unless node.is_a?(Model::ModelElement)
        return nil if visited.include?(node.object_id)

        visited.add(node.object_id)

        return node if node.is_a?(Model::Expressions::QueryExpression) && node.id == tag

        attrs = EXPRESSION_CHILDREN[node.class]
        return nil unless attrs

        attrs.each do |attr|
          value = node.public_send(attr)
          case value
          when Array
            value.each do |val|
              next unless val.is_a?(Model::ModelElement)

              result = find_query_in_expression(val, tag, visited)
              return result if result
            end
          when Model::ModelElement
            result = find_query_in_expression(value, tag, visited)
            return result if result
          end
        end

        nil
      end

      def function_rule_procedure?(node)
        return false unless node

        node.is_a?(Model::Declarations::Function) ||
          node.is_a?(Model::Declarations::Rule) ||
          node.is_a?(Model::Declarations::Procedure)
      end

      # Handle prefixed tags like wr:WR1, ip:IP1, ur:UR1
      def handle_prefixed_tag(tag, containing_scope, model, schema_ids)
        prefix, id = tag.split(":")
        return nil unless id

        collection_attr = case prefix.downcase
                          when "wr" then :where_rules
                          when "ip" then :informal_propositions
                          when "ur" then :unique_rules
                          end
        return nil unless collection_attr

        collection = get_collection(containing_scope, collection_attr)
        if collection
          found = collection.find { |item| item.is_a?(Model::ModelElement) && item.id == id }
          return found if found
        end

        schema_ids.each do |schema_id|
          full_path = "#{schema_id}.#{tag.tr(':', '.')}"
          found = safe_find(model, full_path)
          return found if found
        end

        nil
      end

      # Find target for remarks inside WHERE clauses by scanning source lines
      # for `WHERE <id>:` patterns. Lives here (not in ScopeResolver) because
      # it's about WHERE-rule membership, not scope membership.
      def find_target_in_where_clause(scope, tag, remark_line)
        return nil unless supports_where_rules?(scope)

        where_rules = get_collection(scope, :where_rules)
        return nil unless where_rules&.any?

        where_clause_lines = where_clause_line_index

        where_rules.each do |wr|
          next unless wr.id

          where_clause_lines.fetch(wr.id, []).each do |line_num|
            next unless line_num < remark_line

            return create_remark_item(wr, tag) if remark_line.between?(line_num, line_num + 5)
          end
        end

        nil
      end

      # Single scan over the source lines mapping each `WHERE <id>:` label to
      # its 1-based line number, so per-remark lookups stop re-testing every
      # line against every WHERE rule's regex.
      def where_clause_line_index
        @where_clause_line_index ||= begin
          index = Hash.new { |h, k| h[k] = [] }
          source_lines_for_where_clause.each_with_index do |line, idx|
            if (match = line.match(WHERE_CLAUSE_PATTERN))
              index[match[1]] << (idx + 1)
            end
          end
          index
        end
      end

      def source_lines_for_where_clause
        # @source is set for the duration of `attach`; freed at the end.
        @source_lines_for_where_clause ||= @source.lines
      end

      def find_node_in_statement(stmt, tag)
        case stmt
        when Model::Statements::Alias
          return stmt if stmt.id == tag
        when Model::Statements::Repeat
          return stmt if stmt.id == tag
        when Model::Expressions::QueryExpression
          return stmt if stmt.id == tag
        end
        nil
      end

      def build_scope_path(node)
        return nil unless node

        parts = []
        current = node

        while current
          if current.is_a?(Model::ModelElement) && current.id
            parts.unshift(current.id)
          end

          break if current.is_a?(Model::Declarations::Schema)

          current = current.parent
        end

        parts.empty? ? nil : parts.join(".")
      end

      # ----- Path-based lookup -----

      def find_by_exact_path(model, path)
        return nil unless path
        return nil unless repository?(model) || exp_file?(model)

        result = safe_find(model, path)
        return result if result

        normalized = path.tr(":", ".")
        normalized == path ? nil : safe_find(model, normalized)
      end

      # ----- Target creation -----

      def create_implicit_remark_item_at_schema(model, item_id, schema_id)
        return nil unless repository?(model) || exp_file?(model)

        schema = safe_find(model, schema_id)
        return nil unless schema.is_a?(Model::Declarations::Schema)

        # Strip "wr:" prefix convention (e.g. "wr:IP1" → "IP1")
        ip_id = extract_ip_id(item_id)
        if ip_id && supports_informal_propositions?(schema)
          return create_or_find_informal_proposition(schema, ip_id)
        end

        return nil unless supports_remark_items?(schema)

        existing = schema.remark_items&.find { |ri| ri.id == item_id }
        return existing if existing

        create_remark_item(schema, item_id)
      end

      def create_implicit_remark_item(model, path, schema_ids = [])
        return nil unless repository?(model) || exp_file?(model)

        # Handle "wr:IP1" convention: extract parent path and IP id directly
        # so normalize_path doesn't split "wr:IP1" into "wr"."IP1" segments.
        ip_prefix_match = path.match(/\A(.+)\.(\w+):(IP\d+)\z/)
        if ip_prefix_match
          parent_path = ip_prefix_match[1]
          ip_id = ip_prefix_match[3]
          parent = safe_find(model, parent_path)
          if parent.nil? && schema_ids.any?
            schema_ids.each do |schema_id|
              parent = safe_find(model, "#{schema_id}.#{parent_path}")
              break if parent
            end
          end

          if parent && supports_informal_propositions?(parent)
            return create_or_find_informal_proposition(parent, ip_id)
          end
        end

        # A prefixed intermediate segment (wr:WR1.ip:IP2.__note) splits
        # wrong under the generic prefix-normalized walk below, so the
        # segment-aware resolution handles that class: resolve the
        # longest owned prefix (honoring the wr:/ip:/ur: prefixes
        # find() strips) and attach the first unresolved segment as the
        # remark item id on that node — `<rule>.wr:WR1.__note` lands a
        # `__note` item on WR1 (#562), not a `wr` item on the rule.
        segments = path.split(".")
        if segments.length > 2 &&
            segments[0..-2].any? { |segment| segment.include?(":") } && (owned = resolve_longest_owned_prefix(model, path, schema_ids))
          parent, item_id = owned
          return create_item_at_parent(parent, item_id)
        end

        clean_path = normalize_path(path)
        parts = clean_path.split(".")
        return nil if parts.length < 2

        (parts.length - 1).downto(1) do |i|
          parent_path = parts[0...i].join(".")
          item_id = parts[i]

          parent = safe_find(model, parent_path)

          if parent.nil? && schema_ids.any?
            schema_ids.each do |schema_id|
              parent = safe_find(model, "#{schema_id}.#{parent_path}")
              break if parent
            end
          end

          next unless parent

          return create_item_at_parent(parent, item_id)
        end

        nil
      end

      def normalize_path(path)
        return path unless path.include?(":")
        # `__note:two` is one item id (a referable note/example), not a
        # prefix:name pair to split into two path segments.
        return path if path.split(".").last.start_with?("__")

        path_part, _, item_suffix = path.rpartition(":")
        "#{path_part}.#{item_suffix}"
      end

      # Walks the tag's segments from a schema root, honoring the
      # prefix forms find() strips (wr:WR1, ip:IP1, ur:UR1), and
      # returns [node, first_unresolved_segment] for the deepest node
      # the model owns. Nil when nothing resolves.
      def resolve_longest_owned_prefix(model, path, schema_ids)
        candidate_paths = [path]
        schema_ids.each do |schema_id|
          candidate_paths << "#{schema_id}.#{path}"
        end

        candidate_paths.each do |candidate|
          segments = candidate.split(".")
          next if segments.empty?

          owned_path = segments.first
          node = safe_find(model, owned_path)
          next unless node

          segments[1..].each_with_index do |segment, index|
            stepped = safe_find(model, "#{owned_path}.#{segment}")
            # a lazily created remark item is never a path owner
            stepped = nil if stepped.is_a?(Model::Declarations::RemarkItem)
            if stepped.nil?
              return [node, segment] if index.positive?

              break
            end
            owned_path = "#{owned_path}.#{segment}"
            node = stepped
          end
        end

        nil
      end

      def create_item_at_parent(parent, item_id)
        # Strip "wr:" prefix convention (e.g. "wr:IP1" → "IP1")
        ip_id = extract_ip_id(item_id)
        if ip_id && supports_informal_propositions?(parent)
          return create_or_find_informal_proposition(parent, ip_id)
        end

        return nil unless supports_remark_items?(parent)

        existing = parent.remark_items&.find { |ri| ri.id == item_id }
        return existing if existing

        create_remark_item(parent, item_id)
      end

      def create_or_find_informal_proposition(parent, id)
        return nil unless supports_informal_propositions?(parent)

        existing = parent.informal_propositions&.find { |ip| ip.id == id }
        return existing if existing

        ip = Model::Declarations::InformalPropositionRule.new(id: id)
        ip.parent = parent
        parent.informal_propositions ||= []
        parent.informal_propositions << ip
        safe_reset_children_by_id(parent)

        remark_item = Model::Declarations::RemarkItem.new(id: id)
        remark_item.parent = ip
        ip.remark_items ||= []
        ip.remark_items << remark_item
        safe_reset_children_by_id(ip)

        remark_item
      end

      def create_remark_item(parent, id)
        item = Model::Declarations::RemarkItem.new(id: id)
        item.parent = parent
        parent.remark_items ||= []
        parent.remark_items << item
        safe_reset_children_by_id(parent)
        item
      end

      # ----- Remark storage -----

      def add_remark(node, text, format: Model::RemarkFormat::TAIL, tag: nil,
                     placement: nil, region: nil, source_offset: nil)
        return unless node
        return unless node.is_a?(Model::ModelElement)
        # An empty remark body carries no content; storing it produced
        # remarks == [""] entries (GH-363). Bare `--IPn:` informal
        # propositions keep their declarations through
        # create_or_find_informal_proposition, which does not run through
        # here — only the redundant empty-body storage drops.
        return if text.nil? || text.strip.empty?

        if supports_remarks?(node)
          if node_has_remarks?(node)
            node.remarks ||= []
            node.remarks << text
          end

          if tag.nil?
            remark_info = Model::RemarkInfo.new(text: text, format: format,
                                                placement: placement,
                                                region: region,
                                                source_offset: source_offset)
            node.untagged_remarks ||= []
            node.untagged_remarks << remark_info
          end
        end
      end

      # ----- Type predicates -----

      def supports_remarks?(obj)
        obj.is_a?(Model::ModelElement)
      end

      def node_has_remarks?(obj)
        obj.is_a?(Model::HasRemarks)
      end

      def supports_remark_items?(obj)
        obj.is_a?(Model::HasRemarkItems)
      end

      def supports_informal_propositions?(obj)
        obj.is_a?(Model::HasInformalPropositions)
      end

      # Extracts an IP id from a potentially prefixed item_id.
      # "wr:IP1" → "IP1", "IP1" → "IP1", "WR1" → nil
      def extract_ip_id(item_id)
        bare = item_id.sub(/\A\w+:/, "")
        bare.match?(/^IP\d+$/) ? bare : nil
      end

      def supports_where_rules?(obj)
        obj.is_a?(Model::HasWhereRules)
      end

      def repository?(obj)
        obj.is_a?(Model::Repository)
      end

      def exp_file?(obj)
        obj.is_a?(Model::ExpFile)
      end

      def cache?(obj)
        obj.is_a?(Model::Cache)
      end

      def get_schema_ids(model)
        if repository?(model) || exp_file?(model)
          model.schemas.filter_map(&:id)
        else
          []
        end
      end

      # ----- Collection access -----

      # Type-driven collection access — returns all collections for a node's type.
      def collections_on(node)
        attrs = COLLECTION_REGISTRY[node.class]
        return [] unless attrs

        attrs.filter_map do |attr|
          col = node.public_send(attr)
          col if col.is_a?(Array)
        end
      end

      # Type-driven single collection access — returns one named collection if the type has it.
      def get_collection(node, attr_name)
        return nil unless COLLECTION_REGISTRY[node.class]&.include?(attr_name)

        collection = node.public_send(attr_name)
        collection if collection.is_a?(Array)
      end

      # ----- Helpers -----

      def safe_find(model, path)
        return nil unless model

        model.find(path)
      rescue StandardError
        nil
      end

      def safe_reset_children_by_id(obj)
        return unless obj.respond_to?(:reset_children_by_id)

        obj.reset_children_by_id
      end

      def line_content_for(line_num)
        lines = source_lines_for_where_clause
        return "" if line_num < 1 || line_num > lines.length

        lines[line_num - 1]
      end

      def source_line_count
        source_lines_for_where_clause.length
      end
    end
  end
end
