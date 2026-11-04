# frozen_string_literal: true

module Expressir
  module Express
    module Builders
      # Builds inverse_clause nodes.
      class InverseClauseBuilder
        def call(ast_data)
          Builder.build_children(ast_data[:inverse_attr])
        end
      end
    end
  end
end
