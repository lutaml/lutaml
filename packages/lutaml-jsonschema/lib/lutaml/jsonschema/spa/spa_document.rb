# frozen_string_literal: true

module Lutaml
  module Jsonschema
    module Spa
      class SpaDocument < Base
        attribute :metadata, Metadata
        attribute :schemas, SpaSchema, collection: true, initialize_empty: true
        attribute :search_index, SpaSearchEntry, collection: true,
                                                 initialize_empty: true
        attribute :diff, SpaDiffEntry, collection: true,
                                       initialize_empty: true

        json do
          map "metadata", to: :metadata, render_nil: true,
                          render_default: true, render_empty: true
          map "schemas", to: :schemas
          map "searchIndex", to: :search_index
          map "diff", to: :diff
        end

        def self.from_schema_set(schema_set, metadata: nil)
          SpaBuilder.new(schema_set, metadata: metadata).build
        end
      end
    end
  end
end
