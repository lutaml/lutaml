# frozen_string_literal: true

##
## Behaviour metamodel
##
module Lutaml
  module Uml
    class Dependency < TopElement
      skip_reference_registration

      attribute :client, :string, collection: true, default: -> { [] }
      attribute :supplier, :string, collection: true, default: -> { [] }

      yaml do
        map "client", to: :client
        map "supplier", to: :supplier
      end
    end
  end
end
