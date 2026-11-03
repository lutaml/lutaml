# frozen_string_literal: true

module Lutaml
  module Jsonschema
    module Spa
      class SpaLink < Base
        attribute :title, :string
        attribute :description, :string
        attribute :http_method, :string
        attribute :href, :string
        attribute :rel, :string

        json do
          map "title", to: :title
          map "description", to: :description
          map "method", to: :http_method
          map "href", to: :href
          map "rel", to: :rel
        end
      end
    end
  end
end
