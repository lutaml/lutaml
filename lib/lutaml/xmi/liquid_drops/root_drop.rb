# frozen_string_literal: true

module Lutaml
  module Xmi
    module LiquidDrops
      class RootDrop < Liquid::Drop
        def initialize(model, guidance = nil, options = {}) # rubocop:disable Lint/MissingSuper
          @model = model
          @guidance = guidance
          @options = options
          @xmi_root_model = options[:xmi_root_model]
          @id_name_mapping = options[:id_name_mapping]

          @options[:absolute_path] = "::#{model.name}"
        end

        def name
          @model.name
        end

        def packages
          @model.packages.map do |package|
            ::Lutaml::Xmi::LiquidDrops::PackageDrop.new(package, @guidance,
                                                        @options)
          end
        end

        def children_packages
          @model.packages.flat_map(&:children_packages).uniq
        end
      end
    end
  end
end
