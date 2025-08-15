# frozen_string_literal: true

##
## Behaviour metamodel
##
module Lutaml
  module Uml
    class Constraint < TopElement
      attribute :body, :string
      attribute :type, :string
      attribute :weight, :string
      attribute :status, :string

      yaml do
        map "body", to: :body
        map "type", to: :type
        map "weight", to: :weight
        map "status", to: :status
      end
    end
  end
end
