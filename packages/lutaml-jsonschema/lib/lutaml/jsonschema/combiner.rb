# frozen_string_literal: true

module Lutaml
  module Jsonschema
    # Compatibility facade: bundling now lives on the resolution layer
    # (`SchemaSet#bundle`), so every caller shares one traversal/rewrite.
    class Combiner
      def combine(schema_set)
        schema_set.bundle
      end
    end
  end
end
