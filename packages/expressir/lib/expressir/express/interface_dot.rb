# frozen_string_literal: true

module Expressir
  module Express
    # Interface dependency GraphViz emitter — port of eeng
    # kernel/dot-graph.lisp `:interface` graph (parity-ee stage 10).
    #
    # Nodes are schema names (lowercase); edges are USE FROM (default
    # blue) and REFERENCE FROM (default green). An edge with an item
    # list uses arrowhead=curve; a bare interface uses arrowhead=normal.
    class InterfaceDot
      def initialize(root_schema, repository,
                     iface: :both, uf_color: :blue, rf_color: :green,
                     depth: nil, prune: [])
        @root = root_schema
        @repository = repository
        @iface = iface
        @uf_color = uf_color
        @rf_color = rf_color
        @depth = depth
        @prune = Array(prune).map { |n| n.to_s.downcase }
        @by_name = repository.schemas.compact.to_h { |s| [s.id.safe_downcase, s] }
      end

      def write(io = nil)
        owned = io.nil?
        io ||= +""
        schemas, edges = collect
        io << "// -*- Mode: Dot -*-\n\n"
        io << "// Dot File Written by Expressir\n"
        io << "//    #{Expressir::VERSION}\n"
        io << "\ndigraph interfaces {\n"
        io << "  node [shape=none];\n"
        if %i[both use].include?(@iface)
          io << "  edge [color=#{@uf_color}];\n"
          edges.select { |e| e[:kind] == :use }.each do |e|
            head = e[:items] ? "curve" : "normal"
            io << "  #{e[:from]} -> #{e[:to]} [arrowhead=#{head}];\n"
          end
        end
        if %i[both ref].include?(@iface)
          io << "  edge [color=#{@rf_color}];\n"
          edges.select { |e| e[:kind] == :ref }.each do |e|
            head = e[:items] ? "curve" : "normal"
            io << "  #{e[:from]} -> #{e[:to]} [arrowhead=#{head}];\n"
          end
        end
        # Ensure isolated schemas still appear as nodes.
        named = edges.flat_map { |e| [e[:from], e[:to]] }.uniq
        (schemas.map { |s| s.id.downcase } - named).each do |n|
          io << "  #{n};\n"
        end
        io << "}\n"
        owned ? io : nil
      end

      private

      def collect
        visited = {}
        edges = []
        queue = [[@root, 0]]
        until queue.empty?
          schema, level = queue.shift
          key = schema.id.safe_downcase
          next if visited.key?(key)
          next if @prune.include?(key)

          visited[key] = schema

          Array(schema.interfaces).each do |iface|
            target_name = iface_schema_name(iface)
            next unless target_name

            tkey = target_name.safe_downcase
            next if @prune.include?(tkey)
            next if tkey == key

            kind = iface.kind == Model::Declarations::Interface::REFERENCE ? :ref : :use
            next if @iface == :use && kind != :use
            next if @iface == :ref && kind != :ref

            edges << {
              kind: kind,
              items: Array(iface.items).any?,
              from: key,
              to: tkey,
            }

            target = @by_name[tkey]
            next unless target
            next if @depth && level + 1 >= @depth

            queue << [target, level + 1]
          end
        end
        [visited.values, edges.uniq]
      end

      def iface_schema_name(iface)
        iface.schema.is_a?(String) ? iface.schema : iface.schema&.id
      end
    end
  end
end
