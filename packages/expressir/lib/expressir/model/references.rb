# frozen_string_literal: true

module Expressir
  module Model
    module References
      autoload :AttributeReference, "#{__dir__}/references/attribute_reference"
      autoload :GroupReference, "#{__dir__}/references/group_reference"
      autoload :IndexReference, "#{__dir__}/references/index_reference"
      autoload :SimpleReference, "#{__dir__}/references/simple_reference"
    end
  end
end
