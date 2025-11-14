# frozen_string_literal: true

require_relative "base"
require_relative "class_node"

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
