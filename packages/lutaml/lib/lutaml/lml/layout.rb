# frozen_string_literal: true

module Lutaml
  # Diagram layout engines (ELK in-process; Graphviz via lutaml-graphviz).
  module Layout
    autoload :Engine, "lutaml/lml/layout/engine"
    autoload :ElkEngine, "lutaml/lml/layout/elk_engine"
    autoload :ElkGraphBuilder, "lutaml/lml/layout/elk_graph_builder"
    autoload :ElkSvgRenderer, "lutaml/lml/layout/elk_svg_renderer"
    autoload :ElkSvgMarkers, "lutaml/lml/layout/elk_svg_markers"
  end
end
