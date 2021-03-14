module Lutaml
  module LutamlPath
    class DocumentWrapper
      attr_reader :serialized_document, :original_document

      def initialize(document)
        @original_document = document
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

        serialize_to_hash(attr_value)
      end

      def serialize_to_hash(object)
        return object if [String, Integer, Float, FalseClass, TrueClass, Symbol, NilClass, Hash].include?(object.class)

        object.instance_variables.each_with_object({}) do |var, res|
          variable = object.instance_variable_get(var)
          res[var.to_s.gsub("@", "")] = if variable.is_a?(Array)
                                          variable.map do |n|
                                            serialize_to_hash(n)
                                          end
                                        else
                                          if [String, Integer, Float, FalseClass, TrueClass, Symbol, NilClass, Hash].include?(variable.class) || var == :@parent
                                            variable
                                          else
                                            serialize_to_hash(variable)
                                          end
                                        end
        end
      end
    end
  end
end
