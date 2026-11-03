# frozen_string_literal: true

module Lutaml
  module Jsonschema
    module Spa
      class Metadata < Base
        attribute :title, :string
        attribute :version, :string
        attribute :description, :string
        attribute :base_url, :string
        attribute :theme, :string, default: "light"
        attribute :sort_properties, :string
        attribute :appearance, :hash

        json do
          map "title", to: :title
          map "version", to: :version
          map "description", to: :description
          map "baseUrl", to: :base_url
          map "theme", to: :theme
          map "sortProperties", to: :sort_properties
          map "appearance", to: :appearance
        end
      end
    end
  end
end
