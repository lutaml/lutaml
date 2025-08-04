# frozen_string_literal: true

##
## Behaviour metamodel
##
module Lutaml
  module Uml
    class Transition < TopElement
      attribute :source, :string
      attribute :target, :string
      attribute :guard, :string
      attribute :effect, :string

      yaml do
        map "source", to: :source
        map "target", to: :target
        map "guard", to: :guard
        map "effect", to: :effect
      end
    end
  end
end
