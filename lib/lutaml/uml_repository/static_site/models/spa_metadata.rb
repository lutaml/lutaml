# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Models
        class SpaMetadata < SpaBase
          attribute :title, :string
          attribute :description, :string
          attribute :generated, :string
          attribute :generator, :string
          attribute :version, :string
          attribute :homepage, :string
          attribute :repository_url, :string
          attribute :license, :string
          attribute :authors, :string
          attribute :tags, :string, collection: true, initialize_empty: true
          attribute :appearance, :string
          attribute :statistics, SpaStatistics

          json do
            map "title", to: :title
            map "description", to: :description
            map "generated", to: :generated
            map "generator", to: :generator
            map "version", to: :version
            map "homepage", to: :homepage
            map "repository", to: :repository_url
            map "license", to: :license
            map "authors", to: :authors
            map "tags", to: :tags, render_empty: true
            map "appearance", to: :appearance
            map "statistics", to: :statistics
          end
        end
      end
    end
  end
end
