# frozen_string_literal: true

##
## Behaviour metamodel
##
module Lutaml
  module Uml
    class Constraint < TopElement
      attribute :body, :string

      yaml do
        map "body", to: :body
      end
    end
  end
end
