# frozen_string_literal: true

require "lutaml/uml/class"
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
      attr_reader :packages

      # rubocop:disable Rails/ActiveRecordAliases
      def initialize(attributes = {})
        update_attributes(attributes)
      end
      # rubocop:enable Rails/ActiveRecordAliases
      def classes=(value)
        @classes = value.to_a.map { |attributes| Class.new(attributes) }
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
        @primitives = value.to_a.map { |attributes| PrimitiveType.new(attributes) }
      end

      def associations=(value)
        @associations = value.to_a.map do |attributes|
          Association.new(attributes)
        end
      end

      def classes
        @classes || []
      end

      def enums
        @enums || []
      end

      def data_types
        @data_types || []
      end

      def packages
        @packages || []
      end

      def primitives
        @primitives || []
      end

      def associations
        @associations || []
      end
    end
  end
end
