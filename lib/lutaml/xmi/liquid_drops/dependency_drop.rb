# frozen_string_literal: true

module Lutaml
  module Xmi
    module LiquidDrops
      class DependencyDrop < Liquid::Drop
        def initialize(model, options = {}) # rubocop:disable Lint/MissingSuper
          @model = model
          @options = options
          @lookup = options[:lookup]
        end

        def id
          @model.id
        end

        def name
          @model.name
        end

        def ea_type
          @model&.properties&.ea_type
        end

        def documentation
          @model&.documentation&.value
        end

        def connector
          connector = @lookup.fetch_connector(@model.id)
          ::Lutaml::Xmi::LiquidDrops::ConnectorDrop.new(connector, @options)
        end
      end
    end
  end
end
