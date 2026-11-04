# frozen_string_literal: true

module Expressir
  module Express
    # Builds and queries an index of model nodes by source position.
    #
    # One interface (`nearest_node_to`, `node_for_end_scope_at`, `each_node`),
    # one implementation. Extracted from RemarkAttacher so the tree-walk +
    # byte→line translation + nearest-node heuristics live in one place,
    # tested independently of any remark logic.
    #
    # Reference: ISO 10303-11 — the parser yields source spans on ModelElement
    # instances; this module turns those spans into a line-keyed index that
    # remark attachment can query.
    class NodePositionIndex
      EMPTY = [].freeze
      private_constant :EMPTY

      # Single source of truth for "what collections does this node have"
      # lives on the model — each class declares its own via the
      # `collection_attributes` macro. Referenced by both RemarkAttacher
      # and NodePositionIndex via this alias for backward compatibility.
      COLLECTION_REGISTRY = Model::ModelElement.collection_registry

      attr_reader :nodes

      # Semantic entries starting on `line` (node order).
      def starting_at(line)
        semantic_by_line[line] || EMPTY
      end

      # Semantic entries ending on `line` (node order).
      def ending_at(line)
        semantic_by_end_line[line] || EMPTY
      end

      # Semantic entries whose span covers `line` (node order within the
      # covering band).
      def spanning(line)
        band = line / BAND
        bands = span_bands
        return EMPTY unless bands.key?(band)

        bands[band].select { |n| line.between?(n[:line], n[:end_line]) }
      end

      # Semantic entries with end_line < line, ascending by end_line.
      def semantic_ending_before(line)
        sorted = semantic_by_end_line_list
        idx = sorted.bsearch_index { |n| n[:end_line] >= line } || sorted.size
        sorted[0...idx]
      end

      # The first semantic entry (smallest line), for preamble remarks.
      def first_semantic
        first_by_line = semantic_by_line.keys.min
        first_by_line && semantic_by_line[first_by_line]&.first
      end

      # Entries owned by `owner` within any of `collections`, in node order.
      # Identity-keyed: ownership is object identity (the tree-walker's
      # `.equal?` semantics), and value-equal model objects must not
      # collide.
      def children_in(owner, collections)
        per_collection = children_index[owner]
        return EMPTY unless per_collection

        entries = per_collection.values_at(*collections).compact.flatten(1)
        entries.sort_by { |n| node_order(n) }
      end

      # First node (in node order) that is_a?(type), memoized per type.
      def first_node_of_type(type)
        @first_of_type ||= {}
        @first_of_type[type] ||= @nodes.find { |n| n[:node].is_a?(type) }&.dig(:node)
      end

      def semantic_entries
        @semantic_entries ||=
          @nodes.select { |n| n[:line] && semantic?(n[:node]) }
      end

      # Non-vivifying: missed lookups must not materialize keys, or
      # `keys.min`-style queries see phantom lines.
      def semantic_by_line
        @semantic_by_line ||= begin
          h = {}
          semantic_entries.each { |n| (h[n[:line]] ||= []) << n }
          h
        end
      end

      def semantic_by_end_line
        @semantic_by_end_line ||= begin
          h = {}
          semantic_entries.each { |n| (h[n[:end_line]] ||= []) << n if n[:end_line] }
          h
        end
      end

      def semantic_by_end_line_list
        @semantic_by_end_line_list ||=
          semantic_entries.select { |n| n[:end_line] }.sort_by { |n| n[:end_line] }
      end

      def children_index
        @children_index ||= begin
          index = {}.compare_by_identity
          @nodes.each do |n|
            next unless n[:owner] && n[:line]

            per_owner = (index[n[:owner]] ||= {})
            (per_owner[n[:collection]] ||= []) << n
          end
          index
        end
      end

      def span_bands
        @span_bands ||= begin
          bands = Hash.new { |hash, key| hash[key] = [] }
          semantic_entries.each do |n|
            next unless n[:end_line]

            ((n[:line] / BAND)..(n[:end_line] / BAND)).each do |band|
              bands[band] << n
            end
          end
          bands
        end
      end

      BAND = 1024
      private_constant :BAND

      def initialize(model, line_map)
        @model = model
        @line_map = line_map
        @nodes = build_sorted_nodes
        @node_order = nil
      end

      # Returns the most-specific node whose span contains `remark_line`,
      # preferring same-line starts/ends, then smallest containing span.
      # Skips nodes that cannot own such a remark; see {#remark_scope?}.
      def nearest_node_to(remark_line)
        same_start = starting_at(remark_line).select { |n| remark_scope?(n[:node]) }
        return same_start.last[:node] if same_start.any?

        same_end = ending_at(remark_line).select { |n| remark_scope?(n[:node]) }
        return same_end.last[:node] if same_end.any?

        containing = spanning(remark_line).select { |n| remark_scope?(n[:node]) }

        if containing.any?
          exp_file_node = containing.find { |n| n[:node].is_a?(Model::ExpFile) }
          if exp_file_node
            first_schema_offset = exp_file_node[:node].schemas&.first&.source_offset
            if first_schema_offset && remark_line < @line_map.line_number(first_schema_offset)
              return exp_file_node[:node]
            end
          end
          # Prefer non-ExpFile nodes (Schema, Entity, etc.) over ExpFile
          # when both span the same range, since ExpFile is a file-level
          # container and remarks inside a schema belong to the schema.
          candidates = containing.reject { |n| n[:node].is_a?(Model::ExpFile) }
          candidates = containing if candidates.empty?
          candidates.min_by { |n| n[:end_line] - n[:line] }[:node]
        else
          before = semantic_ending_before(remark_line)
          if before.any?
            before.max_by { |n| n[:end_line] }[:node]
          else
            # Remark is before all nodes (e.g., preamble comment before SCHEMA).
            # Attach to the first semantic node.
            first_semantic&.dig(:node)
          end
        end
      end

      # Returns the node whose END_XXX declaration is on `remark_line`, when
      # the line text matches one of the END_XXX keywords. Used to attach
      # remarks that appear immediately after a scope closes.
      def node_for_end_scope_at(remark_line, line_content)
        node_type = case line_content
                    when /END_SCHEMA/i then Model::Declarations::Schema
                    when /END_ENTITY/i then Model::Declarations::Entity
                    when /END_TYPE/i then Model::Declarations::Type
                    when /END_FUNCTION/i then Model::Declarations::Function
                    when /END_PROCEDURE/i then Model::Declarations::Procedure
                    when /END_RULE/i then Model::Declarations::Rule
                    end
        return nil unless node_type

        candidates = (0..2).flat_map do |back|
          ending_at(remark_line - back)
        end.select do |n|
          n[:node].is_a?(node_type) &&
            n[:end_line] <= remark_line && n[:end_line] >= remark_line - 2
        end

        candidates.min_by { |n| node_order(n) }&.dig(:node) ||
          first_node_of_type(node_type)
      end

      private

      def node_order(entry)
        @node_order ||= begin
          map = {}.compare_by_identity
          @nodes.each_with_index { |n, i| map[n] = i }
          map
        end
        @node_order[entry]
      end

      def semantic?(node)
        !node.is_a?(Model::Repository) && !node.is_a?(Model::Cache)
      end

      # Whether a node can own a remark sitting on a line of its own.
      # Distinct from Model::TakesInlineRemark, which asks whether a node can
      # own a remark written AFTER it on the same line: a statement answers
      # yes to both; an interface clause only to that one.
      #
      # An interface clause is indexed (so a remark trailing it can find it
      # via the same-line lookup), but it encloses nothing: an own-line
      # remark below `REFERENCE FROM x;` introduces whatever comes next, and
      # giving it to the clause would both misplace it and lose it, since
      # nothing renders remarks there.
      def remark_scope?(node)
        semantic?(node) && !node.is_a?(Model::Declarations::Interface)
      end

      def build_sorted_nodes
        result = []
        collect_nodes(@model, result, Set.new)
        result.sort_by!.with_index { |n, i| [n[:position] || Float::INFINITY, i] }
        result
      end

      def collect_nodes(node, result, visited, owner: nil, collection: nil)
        return unless node
        return if visited.include?(node.object_id)

        visited.add(node.object_id)

        if node.is_a?(Model::ModelElement) && node.source && node.source_offset
          record_node_position(node, result, owner, collection)
        else
          result << { node: node, position: nil, line: nil, end_line: nil,
                      owner: owner, collection: collection }
        end

        collect_children(node, result, visited)
      end

      def record_node_position(node, result, owner, collection)
        pos = node.source_offset
        valid = position_valid?(pos, node)
        unless valid
          result << { node: node, position: nil, line: nil, end_line: nil,
                      owner: owner, collection: collection }
          return
        end

        line = @line_map.line_number(pos)
        source_end_line = @line_map.line_number(pos + node.source.length)
        children_end_line = children_end_line_for(node)
        end_line = [source_end_line, children_end_line].compact.max || source_end_line

        result << { node: node, position: pos, line: line, end_line: end_line,
                    owner: owner, collection: collection }
      end

      # The parser returns source_offset=0 for leaf nodes (WhereRule) where
      # it cannot determine the actual position. Accept position=0 only when
      # the source is a declaration keyword line — those legitimately start
      # at the beginning of the file.
      def position_valid?(pos, node)
        return true if pos.positive?
        return false unless pos.zero? && node.source

        node.source.to_s.start_with?(
          "SCHEMA", "ENTITY", "TYPE", "FUNCTION",
          "PROCEDURE", "RULE", "CONSTANT", "VARIABLE",
          "USE", "REFERENCE", "END_SCHEMA", "END_ENTITY",
          "END_TYPE", "END_FUNCTION", "END_PROCEDURE",
          "END_RULE", "END_CONSTANT", "END_VARIABLE"
        )
      end

      def children_end_line_for(node)
        end_lines = []

        if node.is_a?(Model::Declarations::Schema)
          Array(node.children).each do |child|
            next unless child.is_a?(Model::ModelElement) && child.source_offset && child.source

            end_lines << @line_map.line_number(child.source_offset + child.source.length)
          end
        end

        each_collection_on(node) do |item|
          next unless item.is_a?(Model::ModelElement) && item.source_offset && item.source

          end_lines << @line_map.line_number(item.source_offset + item.source.length)
        end

        end_lines.max
      end

      def collect_children(node, result, visited)
        if node.is_a?(Model::Declarations::Schema)
          Array(node.children).each do |c|
            collect_nodes(c, result, visited, owner: node, collection: :children)
          end
        end

        each_collection_on(node) do |item, attr|
          collect_nodes(item, result, visited, owner: node, collection: attr)
        end
      end

      # Yields each child in any declared collection on the node (with the
      # collection attribute name), based on the type-driven
      # COLLECTION_REGISTRY. Returns nothing for nodes whose class is not
      # registered.
      def each_collection_on(node)
        attrs = COLLECTION_REGISTRY[node.class]
        return unless attrs

        attrs.each do |attr|
          collection = node.public_send(attr)
          next unless collection.is_a?(Array)

          collection.each { |item| yield(item, attr) }
        end
      end
    end
  end
end
