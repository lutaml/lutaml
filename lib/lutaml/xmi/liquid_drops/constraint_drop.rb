# frozen_string_literal: true

module Lutaml
  module Xmi
    module LiquidDrops
      class ConstraintDrop < Liquid::Drop
        include Parsers::XmiBase

        def initialize(model) # rubocop:disable Lint/MissingSuper
          @model = model
        end

        def name
          HTMLEntities.new.decode(@model.name)
        end

        def type
          @model.type
        end

        def weight
          @model.weight
        end

        def status
          @model.status
        end
      end
    end
  end
end
