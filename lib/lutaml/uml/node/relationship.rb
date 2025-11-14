# frozen_string_literal: true

require_relative "base"
require_relative "has_name"
require_relative "has_type"

module Lutaml
  module Uml
    module Node
      class Relationship < Base
        include HasName
        include HasType

        attr_reader :from, :to

        def from=(value)
          @from = value.to_s
        end

        def to=(value)
          @to = value.to_s
        end
      end
    end
  end
end
