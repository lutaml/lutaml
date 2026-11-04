# frozen_string_literal: true

require "lutaml/lml"
require_relative "graphviz/version"

module Lutaml
  # Graphviz diagram rendering for LutaML models. The renderers register
  # themselves against the model-driven formatter registry owned by
  # lutaml (Lutaml::Formatter.all / .find_by_name), so requiring this file
  # is all a consumer does to make the `graphviz` formatter available.
  # ruby-graphviz and the `dot` toolchain live in this gem only.
  module Graphviz
    class Error < Lutaml::Error; end
  end

  module Formatter
    autoload :Graphviz, "lutaml/graphviz/formatter/graphviz"
  end

  module Layout
    autoload :GraphVizEngine, "lutaml/graphviz/layout/graph_viz_engine"
  end
end

# Force the autoload so the formatter registers in Lutaml::Formatter.all
# as soon as the gem is required.
Lutaml::Formatter::Graphviz
