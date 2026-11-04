# frozen_string_literal: true

module Lutaml
  module Jsonschema
    module Spa
      class SpaSearchEntry < Base
        attribute :name, :string
        attribute :title, :string
        attribute :description, :string
        attribute :type, :string
        attribute :schema_name, :string

        json do
          map "name", to: :name
          map "title", to: :title
          map "description", to: :description
          map "type", to: :type
          map "schemaName", to: :schema_name
        end
      end
    end
  end
end
