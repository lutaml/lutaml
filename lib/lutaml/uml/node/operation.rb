# frozen_string_literal: true

module Lutaml
  module Uml
    module Node
      class Operation < Attribute
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
