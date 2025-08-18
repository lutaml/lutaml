# frozen_string_literal: true

require "lutaml/uml/class"
require "lutaml/uml/instance"
require "lutaml/uml/data_type"
require "lutaml/uml/enum"
require "lutaml/uml/diagram"
require "lutaml/uml/package"
require "lutaml/uml/primitive_type"

module Lutaml
  module Uml
    class Document
      include HasAttributes
      include HasMembers

      attr_accessor :name,
                    :title,
                    :caption,
                    :groups,
                    :fidelity,
                    :fontname,
                    :comments

      # rubocop:disable Rails/ActiveRecordAliases
      def initialize(attributes = {})
      puts attributes
        update_attributes(attributes)
      end

      # rubocop:enable Rails/ActiveRecordAliases
      def requires=(value)
        @requires = value.to_a.map { |attributes| attributes }
      end

      def classes=(value)
        @classes = value.to_a.map { |attributes| Class.new(attributes) }
      end

      def instance=(value)
        @instance = Instance.new(value)
      end

      def data_types=(value)
        @data_types = value.to_a.map { |attributes| DataType.new(attributes) }
      end

      def enums=(value)
        @enums = value.to_a.map { |attributes| Enum.new(attributes) }
      end

      def packages=(value)
        @packages = value.to_a.map { |attributes| Package.new(attributes) }
      end

      def primitives=(value)
        @primitives = value.to_a.map do |attributes|
          PrimitiveType.new(attributes)
        end
      end

      def associations=(value)
        @associations = value.to_a.map do |attributes|
          Association.new(attributes)
        end
      end

      def requires
        @requires ||= []
      end

      def classes
        @classes ||= []
      end

      def instance
        @instance ||= []
      end

      def enums
        @enums ||= []
      end

      def data_types
        @data_types ||= []
      end

      def packages
        @packages ||= []
      end

      def primitives
        @primitives ||= []
      end

      def associations
        @associations ||= []
      end
    end
  end
end
