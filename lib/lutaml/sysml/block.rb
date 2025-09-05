module Lutaml
  module Sysml
    class Block < Lutaml::Uml::Class
      attr_accessor :base_class

      def initialize # rubocop:disable Lint/MissingSuper
        @xmi_id = nil
        @nested_classifier = []
        @stereotype = []
        @namespace = nil
      end

      def name
        if !base_class.nil? && !base_class.name.nil?
          return base_class.name
        end

        nil
      end

      def full_name
        if !base_class.nil? && !base_class.name.nil?
          return base_class.full_name
        end

        nil
      end
    end
  end
end
