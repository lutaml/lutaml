# frozen_string_literal: true

require "open3"
require "set"

module Lutaml
  module Formatter
    class Graphviz < Base
      autoload :HtmlBuilder, "lutaml/graphviz/formatter/graphviz/html_builder"
      autoload :NodeFormatter, "lutaml/graphviz/formatter/graphviz/node_formatter"
      autoload :RelationshipFormatter, "lutaml/graphviz/formatter/graphviz/relationship_formatter"
      autoload :DocumentFormatter, "lutaml/graphviz/formatter/graphviz/document_formatter"

      include HtmlBuilder
      include NodeFormatter
      include RelationshipFormatter
      include DocumentFormatter

      class Attributes < Hash
        def to_s
          to_a
            .reject { |(_k, val)| val.nil? }
            .map { |(a, b)| "#{a}=#{b.inspect}" }
            .join(" ")
        end
      end

      DEFAULT_CLASS_FONT = "Helvetica"

      VALID_TYPES = %i[
        dot xdot ps pdf svg svgz fig png gif jpg jpeg json imap cmapx
      ].freeze

      def initialize(attributes = {})
        super
        setup_default_attributes
        @type = :dot
      end

      attr_reader :graph, :edge, :node

      def type=(value)
        super
        @type = :dot unless VALID_TYPES.include?(@type)
      end

      def format(node)
        dot = super.lines.map(&:rstrip).join("\n")
        generate_from_dot(dot)
      end

      def setup_default_attributes
        @graph = build_graph_attrs
        @edge = build_edge_attrs
        @node = build_node_attrs
      end

      def build_graph_attrs
        Attributes.new.tap do |g|
          g["splines"] = "ortho"
          g["pad"] = "0.5"
          g["ranksep"] = "1.2"
          g["nodesep"] = "1.2"
          g["rankdir"] = "BT"
        end
      end

      def build_edge_attrs
        Attributes.new.tap { |e| e["color"] = "gray50" }
      end

      def build_node_attrs
        Attributes.new.tap { |n| n["shape"] = "box" }
      end

      private :setup_default_attributes, :build_graph_attrs,
              :build_edge_attrs, :build_node_attrs

      protected

      def generate_from_dot(input)
        Lutaml::Layout::GraphVizEngine.new(input: input).render(@type)
      end

      def generate_graph_name(name)
        name.gsub(/[^0-9a-zA-Z]/i, "")
      end
    end
  end
end
