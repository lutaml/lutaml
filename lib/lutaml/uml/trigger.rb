# frozen_string_literal: true

##
## Behaviour metamodel
##
module Lutaml
  module Uml
    class Trigger < TopElement
      attribute :event, :string

      yaml do
        map "event", to: :event
      end
    end
  end
end
