# frozen_string_literal: true

module Lutaml
  module Xmi
    module LiquidDrops
      class GeneralizationDrop < Liquid::Drop
        def initialize(gen, guidance = nil, options = {}) # rubocop:disable Lint/MissingSuper
          @gen = gen
          @guidance = guidance
          @options = options
          @xmi_root_model = options[:xmi_root_model]
          @id_name_mapping = options[:id_name_mapping]
        end

        def id
          @gen.general_id
        end

        def name
          @gen.general_name
        end

        def upper_klass
          @gen.general_upper_klass
        end

        def general
          if @gen.general
            GeneralizationDrop.new(@gen.general, @guidance, @options)
          end
        end

        def has_general?
          !@gen.general.nil?
        end

        def attributes
          @gen.general_attributes
        end

        def type
          @gen.type
        end

        def definition
          @gen.definition
        end

        def stereotype
          @gen.stereotype
        end

        # get attributes without association
        def owned_props(sort: false)
          return [] unless @gen.owned_props

          props = @gen.owned_props
          props = sort_props(props) if sort
          props_to_liquid(props)
        end

        # get attributes with association
        def assoc_props(sort: false)
          return [] unless @gen.assoc_props

          props = @gen.assoc_props
          props = sort_props(props) if sort
          props_to_liquid(props)
        end

        def props_to_liquid(props)
          props.map do |attr|
            GeneralizationAttributeDrop.new(attr, attr.upper_klass,
                                            attr.gen_name, @guidance)
          end
        end

        # get items without association by looping through the generation
        def inherited_props(sort: false)
          return [] unless @gen.inherited_props

          props = @gen.inherited_props
          props = sort_props_with_level(props) if sort
          props_to_liquid(props)
        end

        # get items with association by looping through the generation
        def inherited_assoc_props(sort: false)
          return [] unless @gen.inherited_assoc_props

          props = @gen.inherited_assoc_props
          props = sort_props_with_level(props) if sort
          props_to_liquid(props)
        end

        def sort_props_with_level(arr)
          return [] if arr.nil? || arr.empty?

          # level desc, name_ns asc, name asc
          arr.sort_by { |i| [-i.level, i.name_ns.to_s, i.name.to_s] }
        end

        def sorted_owned_props
          owned_props(sort: true)
        end

        def sorted_assoc_props
          assoc_props(sort: true)
        end

        def sorted_inherited_props
          inherited_props(sort: true)
        end

        def sorted_inherited_assoc_props
          inherited_assoc_props(sort: true)
        end

        def sort_props(arr)
          return [] if arr.nil? || arr.empty?

          arr.sort_by { |i| [i.name_ns.to_s, i.name.to_s] }
        end
      end
    end
  end
end
