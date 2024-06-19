# frozen_string_literal: true

require "lutaml/uml/node/base"
require "lutaml/uml/node/class_node"

module Lutaml
  module Uml
    module Node
      class Document < Base
        attr_reader :classes

        def classes=(value)
          @classes = value.to_a.map { |attributes| ClassNode.new(attributes) }
        end
      end
    end
  end
end
