# frozen_string_literal: true

module Lutaml
  module Xmi
    module LiquidDrops
      class AssociationDrop < Liquid::Drop
        def initialize(association, options = {}) # rubocop:disable Lint/MissingSuper
          @model = association
          @options = options
          @lookup = options[:lookup]
        end

        def xmi_id
          @model.xmi_id
        end

        def member_end
          @model.member_end
        end

        def member_end_type
          @model.member_end_type
        end

        def member_end_cardinality
          ::Lutaml::Xmi::LiquidDrops::CardinalityDrop.new(@model.member_end_cardinality)
        end

        def member_end_attribute_name
          @model.member_end_attribute_name
        end

        def member_end_xmi_id
          @model.member_end_xmi_id
        end

        def owner_end
          @model.owner_end
        end

        def owner_end_xmi_id
          @model.owner_end_xmi_id
        end

        def definition
          @model.definition
        end

        def connector
          connector = @lookup.fetch_connector(@model.xmi_id)
          ::Lutaml::Xmi::LiquidDrops::ConnectorDrop.new(connector, @options)
        end
      end
    end
  end
end
