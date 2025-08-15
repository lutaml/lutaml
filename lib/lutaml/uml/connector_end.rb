# frozen_string_literal: true

##
## Behaviour metamodel
##
module Lutaml
  module Uml
    class ConnectorEnd < TopElement
      attribute :role, :string
      attribute :part_with_port, :string
      attribute :connector, :string

      yaml do
        map "role", to: :role
        map "part_with_port", to: :part_with_port
        map "connector", to: :connector
      end
    end
  end
end
