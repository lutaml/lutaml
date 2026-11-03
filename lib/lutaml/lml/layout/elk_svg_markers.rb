# frozen_string_literal: true

module Lutaml
  module Layout
    # SVG arrow-marker vocabulary and the <defs> block for ElkSvgRenderer.
    # Marker ids are keyed by association member_end_type.
    module ElkSvgMarkers
      EDGE_STROKE = '#666666'

      ARROW_MARKERS = {
        'association' => 'arrow',
        'aggregation' => 'diamond',
        'composition' => 'diamond_filled',
        'generalization' => 'triangle',
        'uses' => 'arrow',
        'direct' => 'arrow'
      }.freeze

      MARKER_SHAPES = {
        'arrow' => %(<path d="M 0 0 L 10 5 L 0 10 z" fill="#{EDGE_STROKE}"/>),
        'triangle' => %(<path d="M 0 0 L 12 5 L 0 10 z" fill="white" stroke="#{EDGE_STROKE}"/>),
        'diamond' => %(<path d="M 0 4 L 7 0 L 14 4 L 7 8 z" fill="white" stroke="#{EDGE_STROKE}"/>),
        'diamond_filled' => %(<path d="M 0 4 L 7 0 L 14 4 L 7 8 z" fill="#{EDGE_STROKE}"/>)
      }.freeze

      def arrow_marker(edge)
        edge_type = edge.properties&.fetch('member_end_type', nil)
        ARROW_MARKERS.fetch(edge_type.to_s, 'arrow')
      end

      def defs
        MARKER_SHAPES.filter_map { |id, path| marker_def(id, path) }.join("\n")
      end

      private

      def marker_def(id, path)
        w, h = id.start_with?('diamond') ? %w[14 8] : %w[10 10]
        %(<marker id="#{id}" viewBox="0 0 #{w} #{h}" refX="9" refY="4" ) +
          %(markerWidth="#{w}" markerHeight="#{h}" ) +
          %(orient="auto-start-reverse">#{path}</marker>)
      end
    end
  end
end
