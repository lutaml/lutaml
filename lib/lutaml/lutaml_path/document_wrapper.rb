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
    end
  end
end
