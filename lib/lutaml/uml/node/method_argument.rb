# frozen_string_literal: true

require_relative "base"
require_relative "has_name"
require_relative "has_type"

module Lutaml
  module Uml
    module Node
      class MethodArgument < Base
        include HasName
        include HasType
      end
    end
  end
end
