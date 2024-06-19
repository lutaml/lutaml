# frozen_string_literal: true

require "lutaml/uml/node/base"
require "lutaml/uml/node/has_name"
require "lutaml/uml/node/has_type"

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
