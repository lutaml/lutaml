# frozen_string_literal: true

module Expressir
  module Express
    module Builders
      # Builds simple ID nodes (simple_id, schema_id, entity_id, etc.)
      # These return a string, not a Model object.
      class SimpleIdBuilder
        include ::Expressir::Express::Builders::Helpers

        def call(ast_data)
          extract_text(ast_data[:str]) || extract_text(ast_data[:simple_id]&.dig(:str))
        end
      end
    end
  end
end
