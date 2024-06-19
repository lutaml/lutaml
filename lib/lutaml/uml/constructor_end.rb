# frozen_string_literal: true

##
## Behaviour metamodel
##
module Lutaml
  module Uml
    class ConnectorEnd < TopElement
      attr_accessor :role, :part_with_port, :connector

      def initialize
        @role = nil
      end
    end
  end
end
