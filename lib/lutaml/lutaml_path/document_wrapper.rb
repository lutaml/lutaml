module Lutaml
  class DocumentWrapper
    attr_reader :document

    def initialize(document)
      @document = document
    end

    # Method for traversing document` structure
    # example for lutaml: wrapper.find('//#main-doc/main-class/nested-class')
    # Need to return descendant of Lutaml::LutamlPath::EntryWrapper
    def find(path)
      raise ArgumentError, "implement #find!"
    end
  end
end
