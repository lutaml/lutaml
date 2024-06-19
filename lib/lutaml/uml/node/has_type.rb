# frozen_string_literal: true

module Lutaml
  module Uml
    module Node
      module HasType
        attr_reader :type

        def type=(value)
          @type = value.to_s
        end
      end
    end
  end
end
