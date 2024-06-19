# frozen_string_literal: true

##
## Behaviour metamodel
##
module Lutaml
  module Uml
    class Transition < TopElement
      attr_accessor :source, :target, :guard, :effect
    end
  end
end
