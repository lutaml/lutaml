# frozen_string_literal: true

require_relative "base"
require_relative "has_name"
require_relative "has_type"

module Lutaml
  module Uml
    module Node
      class Attribute < Base
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

        VALID_ACCESS = %w[public private protected package].freeze

        def access=(value)
          @access = value.to_s
        end
      end
    end
  end
end
