require "jmespath"

module Lutaml
  module LutamlPath
    class DocumentWrapper
      attr_reader :serialized_document

      def initialize(document)
        @serialized_document = serialize_document(document)
      end

      # Method for traversing document` structure
      # example for lutaml: wrapper.find('//#main-doc/main-class/nested-class')
      # Need to return descendant of Lutaml::LutamlPath::EntryWrapper
      def find(path)
        JMESPath.search(path, serialized_document)
      end

      protected

      def serialize_document(_path)
        raise ArgumentError, "implement #serialize_document!"
      end
    end
  end
end
