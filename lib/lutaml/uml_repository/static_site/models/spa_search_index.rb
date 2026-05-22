# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Models
        class SpaSearchIndex < SpaBase
          attribute :version, :string, default: "1.0.0"
          attribute :fields, :hash, collection: true, default: -> { [] }
          attribute :ref, :string, default: "id"
          attribute :document_store, SpaSearchEntry, collection: true,
                                                     default: -> { [] }
          attribute :pipeline, :string, collection: true,
                                        default: -> {
                                          %w[stemmer stopWordFilter]
                                        }

          json do
            map "version", to: :version, render_default: true
            map "fields", to: :fields, render_default: true
            map "ref", to: :ref, render_default: true
            map "documentStore", to: :document_store
            map "pipeline", to: :pipeline, render_default: true
          end
        end
      end
    end
  end
end
