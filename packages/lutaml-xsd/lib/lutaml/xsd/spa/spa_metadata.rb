# frozen_string_literal: true

module Lutaml
  module Xsd
    module Spa
      # Metadata specific to SPA documentation display.
      # This is a model-driven class (not a hash) that gets serialized to JSON
      # for consumption by the Vue.js frontend.
      #
      # @example Creating SPA metadata
      #   metadata = SpaMetadata.new(
      #     title: "My Schema Docs",
      #     name: "my-package",
      #     version: "1.0.0",
      #     authors: [{ "name" => "Jane Doe", "email" => "jane@example.com" }],
      #     tags: ["xml", "schema"],
      #     branding: { "logo_url" => "https://example.com/logo.svg" },
      #     links: { "getting_started" => "https://example.com/docs" }
      #   )
      #
      class SpaMetadata < Lutaml::Model::Serializable
        attribute :generated, :string
        attribute :generator, :string
        attribute :title, :string
        attribute :name, :string
        attribute :version, :string
        attribute :description, :string
        attribute :license, :string
        attribute :license_url, :string
        attribute :authors, :hash, collection: true
        attribute :homepage, :string
        attribute :repository, :string
        attribute :documentation, :string
        attribute :tags, :string, collection: true
        attribute :schema_count, :integer
        attribute :appearance, :hash
        attribute :links, :hash, collection: true

        yaml do
          map "generated", to: :generated
          map "generator", to: :generator
          map "title", to: :title
          map "name", to: :name
          map "version", to: :version
          map "description", to: :description
          map "license", to: :license
          map "license_url", to: :license_url
          map "authors", to: :authors
          map "homepage", to: :homepage
          map "repository", to: :repository
          map "documentation", to: :documentation
          map "tags", to: :tags
          map "schema_count", to: :schema_count
          map "appearance", to: :appearance
          map "links", to: :links
        end
      end
    end
  end
end
