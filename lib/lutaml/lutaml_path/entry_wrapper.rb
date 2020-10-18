module Lutaml
  module LutamlPath
    # Class wrapper for supported by
    #   lutaml entries(express entity, lutaml `class`|`enum` etc)
    class EntryWrapper
      attr_reader :entry, :attributes, :id

      def initialize(entry)
        @entry = entry
      end

      def attributes(path)
        raise ArgumentError, "implement #attributes!"
      end

      def id(path)
        raise ArgumentError, "implement #id!"
      end
    end
  end
end
