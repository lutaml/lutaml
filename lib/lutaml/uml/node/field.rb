# frozen_string_literal: true

require "lutaml/uml/node/base"
require "lutaml/uml/node/has_name"
require "lutaml/uml/node/has_type"

module Lutaml
  module Uml
    module Node
      class Field < Base
        include HasName
        include HasType

        def initialize(attributes = {})
          @access = "public"

          super
        end

        attr_reader :static, :access

        def static=(value)
          @static = !!value
        end

        def access=(value)
          @access = value.to_s # TODO: Validate?
        end
      end
    end
  end
end
