# frozen_string_literal: true

module Lutaml
  module UmlRepository
    class ClassLookupIndex
      EA_OBJECT_ID_KEY = :ea_object_id

      def initialize(classes)
        @by_xmi_id = {}
        @by_object_id = {}

        classes.each do |klass|
          @by_xmi_id[klass.xmi_id] = klass if klass.xmi_id
          index_by_ea_object_id(klass)
        end
      end

      def by_xmi_id(xmi_id)
        @by_xmi_id[xmi_id]
      end

      def by_object_id(object_id)
        @by_object_id[object_id]
      end

      private

      def index_by_ea_object_id(klass)
        model_class = klass.class
        return unless model_class.is_a?(Class)
        return unless model_class < Lutaml::Model::Serializable
        return unless model_class.attributes.key?(EA_OBJECT_ID_KEY)
        return unless klass.ea_object_id

        @by_object_id[klass.ea_object_id] = klass
      end
    end
  end
end
