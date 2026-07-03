# frozen_string_literal: true

module Lutaml
  module Xmi
    module LiquidDrops
      class SourceTargetDrop < Liquid::Drop
        def initialize(model, options = {}) # rubocop:disable Lint/MissingSuper
          @model = model
          @options = options
          @lookup = options[:lookup]
        end

        def idref
          @model.idref
        end

        def name
          @model&.role&.name
        end

        def type
          @model&.model&.name
        end

        def documentation
          @model&.documentation&.value
        end

        def multiplicity
          @model&.type&.multiplicity
        end

        def aggregation
          @model&.type&.aggregation
        end

        def stereotype
          @lookup.doc_node_attribute_value(@model.idref, "stereotype")
        end
      end
    end
  end
end
