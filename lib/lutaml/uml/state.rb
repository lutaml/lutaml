# frozen_string_literal: true

##
## Behaviour metamodel
##
module Lutaml
  module Uml
    class State < Vertex
      attr_accessor :exit, :entry, :do_activity
    end
  end
end
