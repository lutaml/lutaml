# frozen_string_literal: true

module Lutaml
  module Xmi
    module LiquidDrops
      class DataTypeDrop < Liquid::Drop
        def initialize(model, options = {}) # rubocop:disable Lint/MissingSuper
          @model = model
          @options = options
          @lookup = options[:lookup]
          @xmi_root_model = options[:xmi_root_model]
        end

        def xmi_id
          @model.xmi_id
        end

        def name
          @model.name
        end

        def attributes
          @model.attributes.filter_map do |owned_attr|
            if @options[:with_assoc] || owned_attr.association.nil?
              ::Lutaml::Xmi::LiquidDrops::AttributeDrop.new(owned_attr,
                                                            @options)
            end
          end
        end

        def operations
          @model.operations.map do |operation|
            ::Lutaml::Xmi::LiquidDrops::OperationDrop.new(operation)
          end
        end

        def associations
          @model.associations.filter_map do |assoc|
            ::Lutaml::Xmi::LiquidDrops::AssociationDrop.new(assoc, @options)
          end
        end

        def constraints
          @model.constraints.map do |constraint|
            ::Lutaml::Xmi::LiquidDrops::ConstraintDrop.new(constraint)
          end
        end

        def is_abstract # rubocop:disable Naming/PredicateName,Naming/PredicatePrefix
          @model.is_abstract
        end

        def definition
          @model.definition
        end

        def stereotype
          @model.stereotype&.first
        end
      end
    end
  end
end
