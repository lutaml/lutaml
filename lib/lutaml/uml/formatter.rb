# frozen_string_literal: true

module Lutaml
  module Uml
    module Formatter
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
end

require "lutaml/uml/formatter/graphviz"
