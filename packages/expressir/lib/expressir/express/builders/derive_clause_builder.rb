# frozen_string_literal: true

module Expressir
  module Express
    module Builders
      # Builds derive_clause nodes.
      class DeriveClauseBuilder
        def call(ast_data)
          Builder.build_children(ast_data[:derived_attr])
        end
      end
    end
  end
end
