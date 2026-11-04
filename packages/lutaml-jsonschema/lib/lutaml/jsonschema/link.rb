# frozen_string_literal: true

module Lutaml
  module Jsonschema
    class Link < Base
      attribute :href, :string
      attribute :http_method, :string
      attribute :rel, :string
      attribute :title, :string
      attribute :description, :string
      attribute :schema, Schema
      attribute :target_schema, Schema

      json do
        map "href", to: :href
        map "method", to: :http_method
        map "rel", to: :rel
        map "title", to: :title
        map "description", to: :description
        map "schema", to: :schema
        map "targetSchema", to: :target_schema
      end
    end
  end
end
