# frozen_string_literal: true

module Lutaml
  module UmlRepository
    # O(1) lookup index for UML classes by various identifiers.
    #
    # Replaces O(n) linear scans that were repeated across multiple
    # transformer and serializer classes.
    #
    # @example
    #   index = ClassLookupIndex.new(repository.classes_index)
    #   index.by_xmi_id("EAID_123...")
    #   index.by_object_id(42)
    class ClassLookupIndex
      def initialize(classes)
        @by_xmi_id = {}
        @by_object_id = {}

        classes.each do |klass|
          @by_xmi_id[klass.xmi_id] = klass if klass.xmi_id
          if klass.respond_to?(:ea_object_id) && klass.ea_object_id
            @by_object_id[klass.ea_object_id] = klass
          end
        end
      end

      # @param xmi_id [String]
      # @return [Lutaml::Uml::Class, nil]
      def by_xmi_id(xmi_id)
        @by_xmi_id[xmi_id]
      end

      # @param object_id [String, Integer]
      # @return [Lutaml::Uml::Class, nil]
      def by_object_id(object_id)
        @by_object_id[object_id]
      end
    end
  end
end
