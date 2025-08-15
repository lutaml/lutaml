# frozen_string_literal: true

require_relative "class_definition"

module Lutaml
  module Lml
    module Nodes
      class Instance
        attr_accessor :type, :attributes, :requires

        def initialize(type:, attributes: [], requires: [])
          @type = type
          @attributes = attributes
          @requires = requires
        end
      end
    end
  end
end
