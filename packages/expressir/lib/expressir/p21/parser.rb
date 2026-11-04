# frozen_string_literal: true

module Expressir
  module P21
    # Facade: parse an ISO 10303-21 exchange structure into a
    # {Population} (TODO.eengine/06 step 1).
    module Parser
      module_function

      def parse(source)
        tree = Grammar.new.parse(source)
        Builder.build(tree)
      end
    end
  end
end
