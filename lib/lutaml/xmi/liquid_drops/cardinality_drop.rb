# frozen_string_literal: true

module Lutaml
  module Xmi
    module LiquidDrops
      class CardinalityDrop < Liquid::Drop
        def initialize(model) # rubocop:disable Lint/MissingSuper
          @model = model
        end

        def min
          return nil unless @model

          case @model
          when ::Lutaml::Uml::Cardinality
            @model.min
          else
            @model.lower_value&.value
          end
        end

        def max
          return nil unless @model

          case @model
          when ::Lutaml::Uml::Cardinality
            @model.max
          else
            @model.upper_value&.value
          end
        end
      end
    end
  end
end
