# frozen_string_literal: true

module Lutaml
  module Lml
    class InstanceCollection
      attr_accessor :instances, :imports, :exports, :collections

      def initialize(attributes)
        @instances = []

        attributes.each do |attribute|
          if attribute.key?(:collection)
            @collections = Collection.new(attribute[:collection])
          elsif attribute.key?(:instance)
            @instances << Instance.new(attribute[:instance])
          elsif attribute.key?(:imports)
            @imports = attribute[:imports].map { |import| InstancesImport.new(import) }
          elsif attribute.key?(:exports)
            @exports = attribute[:exports].map { |export| InstancesExport.new(export) }
          end
        end
      end
    end
  end
end