module Lutaml
  module SysMl
    class ConstraintBlock < Block
      def initialize
        @xmi_id = nil
        @nested_classifier = []
        @stereotype = []
        @namespace = nil
      end
    end
  end
end
