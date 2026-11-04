# frozen_string_literal: true

module Expressir
  module Express
    # Resolves the containing scope for a remark line.
    #
    # One interface (`containing_scope_for`), four strategies behind it:
    #   1. O(1) lookup via a precomputed line→scope-name map
    #   2. O(n) position-based fallback against the node index
    #   3. Source-text scan for entity/type/rule boundaries
    #   4. Schema-wide search by name
    #
    # Extracted from RemarkAttacher to deepen the seam: scope lookup is the
    # only concern here, so changes to scope-detection heuristics land in
    # one module and the attacher stops carrying the how.
    class ScopeResolver
      # Match declarations of the scopes we track.
      SCOPE_OPEN_PATTERNS = {
        Model::Declarations::Schema => /^\s*SCHEMA\s+(\w+)/i,
        Model::Declarations::Function => /^\s*FUNCTION\s+(\w+)/i,
        Model::Declarations::Procedure => /^\s*PROCEDURE\s+(\w+)/i,
        Model::Declarations::Rule => /^\s*RULE\s+(\w+)/i,
        Model::Declarations::Entity => /^\s*ENTITY\s+(\w+)/i,
        Model::Declarations::Type => /^\s*TYPE\s+(\w+)/i,
      }.freeze

      SCOPE_CLOSE_PATTERNS = {
        Model::Declarations::Schema => /END_SCHEMA/i,
        Model::Declarations::Function => /END_FUNCTION/i,
        Model::Declarations::Procedure => /END_PROCEDURE/i,
        Model::Declarations::Rule => /END_RULE/i,
        Model::Declarations::Entity => /END_ENTITY/i,
        Model::Declarations::Type => /END_TYPE/i,
      }.freeze

      # Map scope node class → schema-level collection accessor on Schema.
      SCHEMA_COLLECTION_ACCESSOR = {
        Model::Declarations::Entity => lambda(&:entities),
        Model::Declarations::Type => lambda(&:types),
        Model::Declarations::Rule => lambda(&:rules),
      }.freeze

      # Schema-level collections searched when resolving a scope name to a
      # model node. Sourced from Model::Declarations::Schema::SCOPE_DECL_COLLECTIONS
      # so the "which Schema collections hold named scopes" fact lives on
      # the model, not duplicated here.

      def initialize(source:, model:, nodes_with_positions:)
        @source = source
        @model = model
        @nodes_with_positions = nodes_with_positions
        @scope_map = nil
        @source_lines = nil
        @position_buckets = nil
      end

      # Line-band width for the position fallback index.
      BUCKET_LINES = 1024

      # Returns the innermost Model::ScopeContainer whose source span contains
      # the given 1-based remark line, or nil if none is found.
      def containing_scope_for(remark_line)
        scope = find_by_name(remark_line)
        scope ||= find_by_position(remark_line)
        scope
      end

      # Source-text fallback: scan backwards from remark_line for the
      # entity/type/rule declaration that contains it. Used by the attacher
      # when both name- and position-based lookup miss (e.g. for IP tags
      # whose target is a Type/Entity/Rule declared on a previous line).
      def find_by_source_text(remark_line)
        entity_state = { line: nil, name: nil }
        type_state = { line: nil, name: nil }
        rule_state = { line: nil, name: nil }

        source_lines.each_with_index do |line, idx|
          line_num = idx + 1

          case line
          when /^\s*ENTITY\s+(\w+)/i
            entity_state = { line: line_num, name: $1 }
          when /^\s*END_ENTITY/i
            return find_in_schema(Model::Declarations::Entity, entity_state[:name]) if span_contains?(entity_state, remark_line, line_num)

            entity_state = { line: nil, name: nil }
          when /^\s*TYPE\s+(\w+)/i
            type_state = { line: line_num, name: $1 }
          when /^\s*END_TYPE/i
            return find_in_schema(Model::Declarations::Type, type_state[:name]) if span_contains?(type_state, remark_line, line_num)

            type_state = { line: nil, name: nil }
          when /^\s*RULE\s+(\w+)/i
            rule_state = { line: line_num, name: $1 }
          when /^\s*END_RULE/i
            return find_in_schema(Model::Declarations::Rule, rule_state[:name]) if span_contains?(rule_state, remark_line, line_num)

            rule_state = { line: nil, name: nil }
          end
        end

        nil
      end

      private

      def span_contains?(state, remark_line, end_line)
        state[:line] && remark_line >= state[:line] && remark_line <= end_line
      end

      # --- Strategy 1: precomputed line → scope-name map ---

      def find_by_name(remark_line)
        scope_name = scope_map[remark_line]
        return nil unless scope_name
        return nil unless @model

        @model.schemas.each do |schema|
          return schema if schema.id == scope_name

          Model::Declarations::Schema::SCOPE_DECL_COLLECTIONS.each do |decl_type|
            collection = schema.public_send(decl_type)
            next unless collection.is_a?(Array)

            found = collection.find { |n| n.id == scope_name }
            return found if found
          end
        end

        nil
      end

      # Lazily build, on first lookup, the line → scope-name table.
      # O(file_lines) scan; subsequent lookups are O(1).
      def scope_map
        @scope_map ||= build_scope_map
      end

      # Source split into lines, computed once per resolver: both the
      # scope-map build and find_by_source_text need it, and re-splitting the
      # whole source per lookup dominates remark attachment on large files.
      def source_lines
        @source_lines ||= @source.lines
      end

      def build_scope_map
        lines = source_lines
        map = {}
        return map if lines.empty?

        stack = [] # array of { type: Class, name: String }

        lines.each_with_index do |line, idx|
          line_num = idx + 1

          SCOPE_OPEN_PATTERNS.each do |klass, pattern|
            stack << { type: klass, name: $1 } if line =~ pattern
          end

          SCOPE_CLOSE_PATTERNS.each do |klass, pattern|
            next unless line&.match?(pattern)
            next unless stack.last && stack.last[:type] == klass

            stack.pop
          end

          map[line_num] = stack.last&.dig(:name)
        end

        map
      end

      # --- Strategy 2: position-based fallback against the node index ---

      # Nodes bucketed by 1024-line bands: a node spanning [line, end_line]
      # is registered in every band it overlaps, so a remark-line lookup only
      # scans nodes that can possibly contain it. Bucket order preserves the
      # original index order, so select+reverse_each semantics are unchanged.
      def position_buckets
        @position_buckets ||= begin
          buckets = Hash.new { |h, k| h[k] = [] }
          @nodes_with_positions.each do |n|
            next unless n[:line] && n[:end_line]

            ((n[:line] / BUCKET_LINES)..(n[:end_line] / BUCKET_LINES)).each do |b|
              buckets[b] << n
            end
          end
          buckets
        end
      end

      def find_by_position(remark_line)
        containing = position_buckets[remark_line / BUCKET_LINES].select do |n|
          remark_line.between?(n[:line], n[:end_line]) &&
            !n[:node].is_a?(Model::Repository) && !n[:node].is_a?(Model::Cache)
        end

        containing.reverse_each do |n|
          return n[:node] if n[:node].is_a?(Model::ScopeContainer)
        end

        nil
      end

      # --- Schema-wide name search (used by source-text fallback) ---

      def find_in_schema(node_class, name)
        return nil unless @model && name

        accessor = SCHEMA_COLLECTION_ACCESSOR[node_class]
        return nil unless accessor

        @model.schemas.each do |schema|
          found = accessor.call(schema)&.find { |n| n.id == name }
          return found if found
        end

        nil
      end
    end
  end
end
