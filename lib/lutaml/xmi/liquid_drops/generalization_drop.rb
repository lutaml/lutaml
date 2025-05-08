# frozen_string_literal: true

module Lutaml
  module XMI
    class GeneralizationDrop < Liquid::Drop
      include Parsers::XMIBase

      def initialize(gen, guidance = nil, options = {}) # rubocop:disable Lint/MissingSuper
        @gen = gen
        @looped_general_item = false
        @inherited_props = []
        @inherited_assoc_props = []
        @guidance = guidance
        @options = options
        @xmi_root_model = options[:xmi_root_model]
        @id_name_mapping = options[:id_name_mapping]
      end

      def id
        @gen[:general_id]
      end

      def name
        @gen[:general_name]
      end

      def upper_klass
        @gen[:general_upper_klass]
      end

      def general
        if @gen[:general]
          GeneralizationDrop.new(@gen[:general], @guidance, @options)
        end
      end

      def has_general?
        !!@gen[:general]
      end

      def attributes # rubocop:disable Metrics/MethodLength
        attrs = @gen[:general_attributes]
        attrs.each do |i|
          name_ns = case i[:type_ns]
                    when "core", "gml"
                      upper_klass
                    else
                      i[:type_ns]
                    end
          name_ns = upper_klass if name_ns.nil?

          i[:name_ns] = name_ns
          i[:name] = "" if i[:name].nil?
        end
      end

      def type
        @gen[:type]
      end

      def definition
        @gen[:definition]
      end

      def stereotype
        @gen[:stereotype]
      end

      # get attributes without association
      def owned_props(sort: false)
        return [] unless attributes

        props = attributes.select { |attr| attr[:association].nil? }
        props = sort_props(props) if sort
        props_to_liquid(props)
      end

      # get attributes with association
      def assoc_props(sort: false)
        return [] unless attributes

        props = attributes.select { |attr| attr[:association].nil? == false }
        props = sort_props(props) if sort
        props_to_liquid(props)
      end

      def props_to_liquid(props)
        props.map do |attr|
          GeneralizationAttributeDrop.new(attr, upper_klass, name, @guidance)
        end
      end

      # get items without association by looping through the generation
      def inherited_props(sort: false)
        loop_general_item unless @looped_general_item

        props = @inherited_props.reverse
        props = sort_props_with_level(props) if sort
        props_hash_to_liquid(props)
      end

      # get items with association by looping through the generation
      def inherited_assoc_props(sort: false)
        loop_general_item unless @looped_general_item

        props = @inherited_assoc_props.reverse
        props = sort_props_with_level(props) if sort
        props_hash_to_liquid(props)
      end

      def sort_props_with_level(arr)
        return [] if arr.nil? || arr.empty?

        # level desc, name_ns asc, name asc
        arr.sort_by { |i| [-i[:level], i[:attr][:name_ns], i[:attr][:name]] }
      end

      def props_hash_to_liquid(prop_hash_arr)
        prop_hash_arr.map do |prop_hash|
          GeneralizationAttributeDrop.new(
            prop_hash[:attr],
            prop_hash[:gen_upper_klass],
            prop_hash[:gen_name],
            prop_hash[:guidance],
          )
        end
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

        arr.sort_by { |i| [i[:name_ns], i[:name]] }
      end

      def loop_general_item # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
        general_item = general
        level = 0

        while general_item.has_general?
          gen_upper_klass = general_item.upper_klass
          gen_name = general_item.name
          # reverse the order to show super class first
          general_item.attributes.reverse_each do |attr|
            attr_hash = {
              attr: attr,
              gen_upper_klass: gen_upper_klass,
              gen_name: gen_name,
              guidance: @guidance,
            }
            attr_hash[:level] = level

            if attr[:association]
              @inherited_assoc_props << attr_hash
            else
              @inherited_props << attr_hash
            end
          end

          level += 1
          general_item = general_item.general
        end

        @looped_general_item = true
      end
    end
  end
end
