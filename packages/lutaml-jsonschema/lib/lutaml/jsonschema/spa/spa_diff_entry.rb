# frozen_string_literal: true

module Lutaml
  module Jsonschema
    module Spa
      # One classified change from a baseline schema, for the SPA change view.
      class SpaDiffEntry < Base
        attribute :schema_name, :string
        attribute :pointer, :string
        attribute :classification, :string
        attribute :detail, :string

        json do
          map "schemaName", to: :schema_name
          map "pointer", to: :pointer
          map "classification", to: :classification
          map "detail", to: :detail
        end
      end
    end
  end
end
