# frozen_string_literal: true

module Expressir
  module Express
    module Builders
      # Builds reference nodes (attribute_ref, entity_ref, etc.).
      # Returns SimpleReference for all reference types.
      class ReferenceBuilder
        include ::Expressir::Express::Builders::Helpers

        def call(ast_data)
          id = extract_id_ref(ast_data)
          Expressir::Model::References::SimpleReference.new(id: id)
        end
      end
    end
  end
end
