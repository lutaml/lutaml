# frozen_string_literal: true

##
## Behaviour metamodel
##
module Lutaml
  module Uml
    class State < Vertex
      attribute :exit, :string
      attribute :entry, :string
      attribute :do_activity, :string

      yaml do
        map "exit", to: :exit
        map "entry", to: :entry
        map "do_activity", to: :do_activity
      end
    end
  end
end
