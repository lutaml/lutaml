# frozen_string_literal: true

module Lutaml
  module XMI
    class GeneralizationAttributeDrop < Liquid::Drop
      def initialize(attr, upper_klass, gen_name) # rubocop:disable Lint/MissingSuper
        @attr = attr
        @upper_klass = upper_klass
        @gen_name = gen_name
      end

      def id
        @attr[:id]
      end

      def name
        @attr[:name]
      end

      def type
        @attr[:type]
      end

      def xmi_id
        @attr[:xmi_id]
      end

      def is_derived
        @attr[:is_derived]
      end

      def cardinality
        ::Lutaml::XMI::CardinalityDrop.new(@attr[:cardinality])
      end

      def definition
        @attr[:definition]
      end

      def association
        @attr[:association]
      end

      def has_association?
        !!@attr[:association]
      end

      def type_ns
        @attr[:type_ns]
      end

      def upper_klass
        @upper_klass
      end

      def gen_name
        @gen_name
      end

      def name_ns
        name_ns = case @attr[:type_ns]
                  when "core", "gml"
                    upper_klass
                  else
                    @attr[:type_ns]
                  end

        name_ns = upper_klass if name_ns.nil?
        name_ns
      end
    end
  end
end
