# frozen_string_literal: true

require "lutaml/uml/node/field"
require "lutaml/uml/node/method_argument"
require "lutaml/uml/node/has_name"

module Lutaml
  module Uml
    module Node
      class Method < Field
        include HasName

        attr_reader :abstract, :arguments

        def abstract=(value)
          @abstract = !!value
        end

        def arguments=(value)
          @arguments = value.to_a.map do |attributes|
            MethodArgument.new(attributes)
          end
        end
      end
    end
  end
end
