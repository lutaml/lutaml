# frozen_string_literal: true

##
## Behaviour metamodel
##
module Lutaml
  module Uml
    class Connector < TopElement
      attr_accessor :kind, :connector_end

      def initialize
        @name = nil
        @xmi_id = nil
        @xmi_uuid = nil
        @connector_end = []
        @namespace = nil
        @kind = nil
      end
    end
  end
end
