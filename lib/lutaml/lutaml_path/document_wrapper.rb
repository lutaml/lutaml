module Lutaml
  module LutamlPath
    class DocumentWrapper
      attr_reader :serialized_document

      def initialize(document)
        @serialized_document = serialize_document(document)
      end

      def to_liquid
        serialized_document
      end

      protected

      def serialize_document(_path)
        raise ArgumentError, "implement #serialize_document!"
      end

      def serialize_value(attr_value)
        if attr_value.is_a?(Array)
          return attr_value.map(&method(:serialize_to_hash))
        end

        attr_value
      end

      def serialize_to_hash(object)
        object.instance_variables.each_with_object({}) do |var, res|
          variable = object.instance_variable_get(var)
          if variable.is_a?(Array)
            res[var.to_s.gsub("@", '')] = variable.map { |n| serialize_to_hash(n) }
          else
            res[var.to_s.gsub("@", '')] = variable
          end
        end
      end
    end
  end
end
