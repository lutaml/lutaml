# frozen_string_literal: true

require "ruby-graphviz"
require "lutaml/layout/engine"

module Lutaml
  module Layout
    class GraphVizEngine < Engine
      def render(type)
        Open3.popen3("dot -T#{type}") do |stdin, stdout, _stderr, _wait|
          stdout.binmode
          stdin.puts(input)
          stdin.close
          stdout.read
        end
      end
    end
  end
end
