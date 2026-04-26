# frozen_string_literal: true

module Lutaml
  module Xmi
    module LiquidDrops
      class EnumDrop < Liquid::Drop
        def initialize(model, options = {}) # rubocop:disable Lint/MissingSuper
          @model = model
          @options = options
          @lookup = options[:lookup]
        end

        def xmi_id
          @model.xmi_id
        end

        def name
          @model.name
        end

        def values
          @model.values.map do |value|
            ::Lutaml::Xmi::LiquidDrops::EnumOwnedLiteralDrop.new(value)
          end
        end

        def definition
          @model.definition
        end

        def stereotype
          @model.stereotype&.first
        end

        # @return name of the upper packaged element
        def upper_packaged_element
          if @options[:with_gen]
            e = @lookup.find_upper_level_packaged_element(@model.xmi_id)
            e&.name
          end
        end

        def subtype_of
          @lookup.find_subtype_of_from_owned_attribute_type(@model.xmi_id)
        end
      end
    end
  end
end
