# frozen_string_literal: true

module Lutaml
  module Layout
    # In-process layout engine backed by elkrb (pure-Ruby ELK). The input
    # is an already-built Elkrb::Graph; rendering produces standalone SVG.
    class ElkEngine < Engine
      def render(_type)
        require 'elkrb'
        Elkrb::Layout::LayoutEngine.layout(@input, algorithm: 'layered')
        ElkSvgRenderer.new.render(@input)
      end
    end
  end
end
