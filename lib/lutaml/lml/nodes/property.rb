# frozen_string_literal: true

module Lutaml
  module Lml
    module Nodes
      class Property
        attr_accessor :name, :value

        def initialize(name:, value:)
          @name = name
          @value = value
        end
      end
    end
  end
end
