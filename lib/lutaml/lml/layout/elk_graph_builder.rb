# frozen_string_literal: true

module Lutaml
  module Layout
    # Builds an Elkrb::Graph: a node per classifier (name, definition,
    # members); an edge per association and parent specializer.
    class ElkGraphBuilder
      CHAR_WIDTH = 7.2
      LINE_HEIGHT = 16.0
      PADDING = 14.0
      MIN_WIDTH = 120.0
      COLLECTIONS = %i[classes enums primitives data_types].freeze
      def build(document)
        graph = elkrb_graph
        add_entities(graph, document)
        add_association_edges(graph, document)
        add_parent_edges(graph, document)
        graph
      end

      private

      def elkrb_graph
        require 'elkrb'
        Elkrb::Graph::Graph.new(id: 'diagram')
      rescue LoadError
        raise Error, 'The elkrb gem is required for ELK layout: add `gem "elkrb"` to your Gemfile'
      end

      def entities(document)
        ([document] + Array(document.packages)).flat_map { |scope| scope_entities(scope) }.flatten.compact
      end

      def scope_entities(scope)
        COLLECTIONS.filter_map do |collection|
          next unless scope.respond_to?(collection)

          scope.public_send(collection)
        end
      end

      def node_for(entity)
        lines = label_lines(entity)
        Elkrb::Graph::Node.new(
          id: entity_id_for(entity.name),
          width: node_width(lines),
          height: PADDING + lines.size * LINE_HEIGHT,
          labels: lines.each_with_index.map do |line, i|
            Elkrb::Graph::Label.new(text: line, x: 0, y: i * LINE_HEIGHT)
          end
        )
      end

      def label_lines(entity)
        lines = [entity.name.to_s]
        if entity.respond_to?(:definition) && !entity.definition.to_s.empty?
          lines << entity.definition.to_s.gsub("\n", ' ')
        end
        Array(entity.attributes).each do |attr|
          lines << attr_line(attr)
        end
        lines
      end

      def attr_line(attr)
        line = "+ #{attr.name}"
        line += ": #{attr.type}" if attr.type && !attr.type.to_s.empty?
        line
      end

      def node_width(lines)
        widest = lines.map(&:length).max || 0
        [widest * CHAR_WIDTH + PADDING, MIN_WIDTH].max
      end

      def entity_id(entity)
        entity.name.to_s.gsub(/[^0-9a-zA-Z_]/, '_')
      end

      def associations(document)
        Array(document.associations)
      end

      def parent_edges(document)
        Array(document.classes).filter_map do |klass|
          next unless klass.respond_to?(:parent_class) && klass.parent_class

          { owner: klass.parent_class, member: klass.name.to_s,
            member_end_type: 'generalization', name: nil }
        end
      end

      def add_entities(graph, document)
        entities(document).each { |entity| graph.children << node_for(entity) }
      end

      def add_association_edges(graph, document)
        associations(document).each { |assoc| graph.edges << edge_for(association_spec(assoc)) }
      end

      def add_parent_edges(graph, document)
        parent_edges(document).each { |edge| graph.edges << edge_for(edge) }
      end

      def edge_for(spec)
        edge = elkrb_edge(spec)
        edge.properties = { 'member_end_type' => spec[:member_end_type].to_s }
        edge.labels = [Elkrb::Graph::Label.new(text: spec[:name].to_s)] if spec[:name]
        edge
      end

      def elkrb_edge(spec)
        require 'elkrb'
        Elkrb::Graph::Edge.new(
          id: "edge_#{spec[:owner]}_#{spec[:member]}",
          sources: [entity_id_for(spec[:owner])],
          targets: [entity_id_for(spec[:member])]
        )
      end

      def association_spec(assoc)
        { owner: assoc.owner_end.to_s, member: assoc.member_end.to_s,
          member_end_type: assoc.member_end_type.to_s, name: assoc.name }
      end

      def entity_id_for(name) = name.to_s.gsub(/[^0-9a-zA-Z_]/, '_')
    end
  end
end
