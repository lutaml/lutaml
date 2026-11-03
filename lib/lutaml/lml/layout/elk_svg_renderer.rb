# frozen_string_literal: true

module Lutaml
  module Layout
    # Renders a laid-out Elkrb::Graph (nodes positioned by the layout) as
    # standalone SVG: rounded-rect nodes with text-line labels and
    # polyline edges with per-type arrow markers.
    class ElkSvgRenderer
      include ElkSvgMarkers

      EDGE_STROKE = ElkSvgMarkers::EDGE_STROKE

      HEADER = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="%<width>s" height="%<height>s" viewBox="0 0 %<width>s %<height>s">
      XML
      NODE_FILL = '#f8f8f8'
      NODE_STROKE = '#333333'

      def render(graph)
        @graph = graph
        @out = +''
        @out << format(HEADER, width: bounds_width, height: bounds_height)
        @out << "<defs>\n#{defs}\n</defs>\n"
        nodes
        edges
        @out << "</svg>\n"
        @out
      end

      private

      def nodes
        @graph.children.each { |node| render_node(node) }
      end

      def render_node(node)
        @out << %(<g transform="translate(#{node.x.to_i},#{node.y.to_i})">)
        @out << node_rect(node)
        node.labels.each_with_index { |label, i| @out << node_label(label, i) }
        @out << '</g>'
      end

      def node_rect(node)
        %(<rect width="#{node.width.to_i}" height="#{node.height.to_i}" rx="6" ) +
          %(fill="#{NODE_FILL}" stroke="#{NODE_STROKE}"/>)
      end

      def node_label(label, index)
        y = ((index + 0.7) * ElkGraphBuilder::LINE_HEIGHT).round(1)
        weight = index.zero? ? ' font-weight="bold"' : ''
        %(<text x="7" y="#{y}" font-family="Helvetica" font-size="12"#{weight}>#{escape(label.text)}</text>)
      end

      def edges
        @graph.edges.each { |edge| render_edge(edge) }
      end

      def render_edge(edge)
        points = edge_points(edge)
        return if points.empty?

        @out << edge_polyline(edge, points)
        edge_label(edge, points)
      end

      def edge_polyline(edge, points)
        pts = points.map { |p| "#{p.x.round(1)},#{p.y.round(1)}" }.join(' ')
        %(<polyline fill="none" stroke="#{EDGE_STROKE}" marker-end="url(##{arrow_marker(edge)})" points="#{pts}"/>)
      end

      def edge_label(edge, points)
        label = Array(edge.labels).first
        return unless label&.text

        @out << edge_label_text(label, edge_anchor(points))
      end

      def edge_anchor(points)
        mid = points[points.size / 2]
        { x: (mid.x + 4).round(1), y: (mid.y - 4).round(1) }
      end

      def edge_label_text(label, anchor)
        %(<text x="#{anchor[:x]}" y="#{anchor[:y]}" font-family="Helvetica" ) +
          %(font-size="10" fill="#{EDGE_STROKE}">#{escape(label.text)}</text>)
      end

      def edge_points(edge)
        sections = Array(edge.sections)
        return [] if sections.empty?

        points = [sections.first.start_point]
        sections.each do |section|
          points.concat(Array(section.bend_points))
          points << section.end_point
        end
        points.compact
      end

      def bounds_width
        extent(:x, :width) + 20
      end

      def bounds_height
        extent(:y, :height) + 20
      end

      def extent(pos, size)
        values = @graph.children.map { |n| n.public_send(pos).to_f + n.public_send(size).to_f }
        [values.max || 0, 0].max.round
      end

      def escape(text)
        text.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
      end
    end
  end
end
