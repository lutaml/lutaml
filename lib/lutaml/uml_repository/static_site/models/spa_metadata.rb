# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module StaticSite
      module Models
        class SpaMetadata < SpaBase
          attribute :generated, :string
          attribute :generator, :string
          attribute :version, :string
          attribute :statistics, SpaStatistics

          json do
            map "generated", to: :generated
            map "generator", to: :generator
            map "version", to: :version
            map "statistics", to: :statistics
          end
        end
      end
    end
  end
end
