# frozen_string_literal: true

module Expressir
  module Express
    module Builders
      # Builds where_clause nodes.
      class WhereClauseBuilder
        def call(ast_data)
          rules_data = ast_data[:list_of_domain_rule] || ast_data[:domain_rule]
          return [] unless rules_data

          rules_data = [rules_data] if rules_data.is_a?(Hash)
          Builder.ensure_array(rules_data).filter_map do |rule|
            Builder.build({ domain_rule: rule })
          end
        end
      end
    end
  end
end
