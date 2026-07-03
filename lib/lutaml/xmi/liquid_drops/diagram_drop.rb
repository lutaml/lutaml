# frozen_string_literal: true

module Lutaml
  module Xmi
    module LiquidDrops
      class DiagramDrop < Liquid::Drop
        def initialize(model, options = {}) # rubocop:disable Lint/MissingSuper
          @model = model
          @options = options
        end

        def xmi_id
          @model.xmi_id
        end

        def name
          @model.name
        end

        def definition
          @model.definition
        end

        def package_id
          @model.package_id if @options[:with_gen]
        end

        def package_name
          @model.package_name if @options[:with_gen]
        end
      end
    end
  end
end
