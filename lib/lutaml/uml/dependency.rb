# frozen_string_literal: true

##
## Behaviour metamodel
##
module Lutaml
  module Uml
    class Dependency < TopElement
      attr_accessor :client, :supplier

      def initialize
        @name = nil
        @xmi_id = nil
        @xmi_uuid = nil
        @client = []
        @supplier = []
        @namespace = nil
      end
    end
  end
end
