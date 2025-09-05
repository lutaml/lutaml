module Lutaml
  module Sysml
    class ConstraintBlock < Block
      def initialize # rubocop:disable Lint/MissingSuper
        @xmi_id = nil
        @nested_classifier = []
        @stereotype = []
        @namespace = nil
      end
    end
  end
end
