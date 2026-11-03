# frozen_string_literal: true

require "json"

module Expressir
  # Mappings from EXPRESS to other modeling notations. These are
  # contributions, not ISO mappings; every decision is documented under
  # docs/interop/.
  module Interop
    autoload :JsonSchema, "#{__dir__}/interop/json_schema"
    autoload :Owl, "#{__dir__}/interop/owl"
  end
end
