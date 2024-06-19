# frozen_string_literal: true

##
## Behaviour metamodel
##

module Lutaml
  module Uml
    class Actor < Classifier
      def initialize
        @name = nil
        @xmi_id = nil
        @stereotype = []
        @generalization = []
        @namespace = nil
      end
    end
  end
end
