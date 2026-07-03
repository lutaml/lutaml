# frozen_string_literal: true

module Lutaml
  module Xmi
    module LiquidDrops
      class AttributeDrop < Liquid::Drop
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

        def type
          @model.type
        end

        def xmi_id
          @model.xmi_id
        end

        def is_derived # rubocop:disable Naming/PredicateName,Naming/PredicatePrefix
          @model.is_derived
        end

        def cardinality
          ::Lutaml::Xmi::LiquidDrops::CardinalityDrop.new(@model.cardinality)
        end

        def definition
          if @options[:with_assoc] && @model.association
            @lookup.loopup_assoc_def(@model.association)
          else
            @model.definition
          end
        end

        def association
          if @options[:with_assoc] && @model.association
            @model.association
          end
        end

        def association_connector
          return unless @model.association

          connector = @lookup.fetch_connector(@model.association)
          if connector
            ::Lutaml::Xmi::LiquidDrops::ConnectorDrop.new(connector, @options)
          end
        end

        def type_ns
          if @options[:with_assoc] && @model.association
            @model.type_ns
          end
        end

        def stereotype
          @lookup.doc_node_attribute_value(@model.xmi_id, "stereotype")
        end
      end
    end
  end
end
