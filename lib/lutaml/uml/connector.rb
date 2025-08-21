# frozen_string_literal: true

##
## Behaviour metamodel
##
module Lutaml
  module Uml
    class Connector < TopElement
      attribute :kind, :string
      attribute :connector_end, :string, collection: true, default: -> { [] }

      yaml do
        map "kind", to: :kind
        map "connector_end", to: :connector_end
      end
    end
  end
end
