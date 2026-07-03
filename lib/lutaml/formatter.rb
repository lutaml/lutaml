# frozen_string_literal: true

module Lutaml
  module Formatter
    autoload :Base, "lutaml/formatter/base"
    autoload :Graphviz, "lutaml/formatter/graphviz"

    class << self
      def all
        @all ||= []
      end

      def find_by_name(name)
        name = name.to_sym

        all.detect { |formatter_class| formatter_class.name == name }
      end
    end
  end
end
