# frozen_string_literal: true

module Lutaml
  module Xmi
    module LiquidDrops
      class PackageDrop < Liquid::Drop
        def initialize(model, guidance = nil, options = {}) # rubocop:disable Lint/MissingSuper
          @model = model
          @guidance = guidance
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

        def absolute_path
          absolute_path_arr = [@model.name]
          e = @lookup.find_upper_level_packaged_element(@model.xmi_id)
          absolute_path_arr << e.name if e

          while e
            e = @lookup.find_upper_level_packaged_element(e.id)
            absolute_path_arr << e.name if e
          end

          absolute_path_arr << "::#{@xmi_root_model.model.name}"
          absolute_path_arr.reverse.join("::")
        end

        def klasses
          @model.classes.map do |klass|
            ::Lutaml::Xmi::LiquidDrops::KlassDrop.new(
              klass,
              @guidance,
              @options.merge(
                {
                  absolute_path: "#{@options[:absolute_path]}::#{name}",
                },
              ),
            )
          end
        end
        alias classes klasses

        def enums
          @model.enums.map do |enum|
            ::Lutaml::Xmi::LiquidDrops::EnumDrop.new(enum, @options)
          end
        end

        def data_types
          @model.data_types.map do |data_type|
            ::Lutaml::Xmi::LiquidDrops::DataTypeDrop.new(data_type, @options)
          end
        end

        def diagrams
          @model.diagrams.map do |diagram|
            ::Lutaml::Xmi::LiquidDrops::DiagramDrop.new(diagram, @options)
          end
        end

        def packages
          @model.packages.map do |package|
            ::Lutaml::Xmi::LiquidDrops::PackageDrop.new(
              package,
              @guidance,
              @options.merge(
                {
                  absolute_path: "#{@options[:absolute_path]}::#{name}",
                },
              ),
            )
          end
        end

        def children_packages
          @model.children_packages
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
