# frozen_string_literal: true

module Lutaml
  module Uml
    class Package < TopElement
      include HasAttributes

      attr_accessor :imports, :contents
      attr_reader :classes, :enums, :data_types, :children_packages

      def initialize(attributes)
        update_attributes(attributes)
        @children_packages ||= packages.map { |pkg| [pkg, pkg.packages, pkg.packages.map(&:children_packages)] }.flatten.uniq
      end

      def classes=(value)
        @classes = value.to_a.map { |attributes| Class.new(attributes) }
      end

      def enums=(value)
        @enums = value.to_a.map { |attributes| Enum.new(attributes) }
      end

      def data_types=(value)
        @data_types = value.to_a.map { |attributes| DataType.new(attributes) }
      end

      def packages=(value)
        @packages = value.to_a.map { |attributes| Package.new(attributes) }
      end

      def diagrams=(value)
        @diagrams = value.to_a.map { |attributes| Diagram.new(attributes) }
      end

      def classes
        @classes || []
      end

      def enums
        @enums || []
      end

      def packages
        @packages || []
      end

      def diagrams
        @diagrams || []
      end
    end
  end
end
