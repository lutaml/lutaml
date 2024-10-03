# frozen_string_literal: true

module Lutaml
  module XMI
    class GeneralizationDrop < Liquid::Drop
      def initialize(gen) # rubocop:disable Lint/MissingSuper
        @gen = gen
        @looped_general_item = false
        @inherited_props = []
        @inherited_assoc_props = []
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
        GeneralizationDrop.new(@gen[:general]) if @gen[:general]
      end

      def has_general?
        !!@gen[:general]
      end

      def attributes
        @gen[:general_attributes]
        # @gen[:general_attributes].map do |attr|
        #   GeneralizationAttributeDrop.new(attr, upper_klass, name)
        # end
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
      def owned_props
        attributes.select do |attr|
          attr[:association].nil?
        end.map do |attr|
          GeneralizationAttributeDrop.new(attr, upper_klass, name)
        end
      end

      # get attributes with association
      def assoc_props
        attributes.select do |attr|
          attr[:association]
        end.map do |attr|
          GeneralizationAttributeDrop.new(attr, upper_klass, name)
        end
      end

      # get items without association by looping through the generation
      def inherited_props
        loop_general_item unless @looped_general_item

        @inherited_props.reverse
      end

      # get items with association by looping through the generation
      def inherited_assoc_props
        loop_general_item unless @looped_general_item

        @inherited_assoc_props.reverse
      end

      def loop_general_item # rubocop:disable Metrics/MethodLength
        general_item = general
        while general_item.has_general?
          gen_upper_klass = general_item.upper_klass
          gen_name = general_item.name
          # reverse the order to show super class first
          general_item.attributes.reverse_each do |attr|
            attr_drop = GeneralizationAttributeDrop.new(attr, gen_upper_klass,
                                                        gen_name)
            if attr[:association]
              @inherited_assoc_props << attr_drop
            else
              @inherited_props << attr_drop
            end
          end

          general_item = general_item.general
        end

        @looped_general_item = true
      end
    end
  end
end
