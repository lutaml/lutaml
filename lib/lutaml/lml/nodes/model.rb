# frozen_string_literal: true

require_relative "class_definition"

module Lutaml
  module Lml
    module Nodes
      class Model
        attr_accessor :name, :class_definitions

        def initialize(name:, class_definitions: [], requires: [])
          @name = name
          @class_definitions = class_definitions
          @requires = requires
        end
      end
    end
  end
end
