# frozen_string_literal: true

module Expressir
  module Express
    module Builders
      # Builds unique_clause nodes.
      class UniqueClauseBuilder
        def call(ast_data)
          rules_data = ast_data[:list_of_unique_rule] || ast_data[:unique_rule]
          return [] unless rules_data

          rules_data = [rules_data] if rules_data.is_a?(Hash)
          Builder.ensure_array(rules_data).filter_map do |rule|
            Builder.build({ unique_rule: rule })
          end
        end
      end
    end
  end
end
