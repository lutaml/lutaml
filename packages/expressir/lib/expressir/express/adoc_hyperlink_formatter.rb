# frozen_string_literal: true

module Expressir
  module Express
    # HyperlinkFormatter variant emitting AsciiDoc xref macros instead
    # of the legacy stepmod +{{{<<express:...>>}}}+ markup: a reference
    # to schema.item renders as +<<schema.item,item>>+, the anchor
    # namespace schema document pages emit (expressir #255 / iso-10303
    # #41). With +subs="+macros"+ source blocks the links go live.
    module AdocHyperlinkFormatter
      # @!visibility private
      def self.included(mod)
        unless mod.superclass <= Expressir::Express::Formatter
          raise Error::FormatterMethodMissingError.new("AdocHyperlinkFormatter",
                                                       "format_references_simple_reference")
        end
      end

      def format_references_simple_reference(node)
        return node.id unless node.base_path

        parts = node.base_path.split(".")
        return node.id if parts.size < 2

        anchor = parts[-2, 2].join(".")
        "<<#{anchor},#{node.id}>>"
      end
    end
  end
end
