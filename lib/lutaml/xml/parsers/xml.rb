require "nokogiri"
require "htmlentities"
require "lutaml/uml/has_attributes"
require "lutaml/uml/document"

module Lutaml
  module Xml
    module Parsers
      # Class for parsing .xml schema files into ::Lutaml::Uml::Document
      class Xml
        def self.set_document(doc)
          @@document = doc
        end

        def self.parse(file)
          new(file).parse
        end

        def initialize(file)
          @file = file
        end

        def parse
          unless defined?(@@document)
            msg = "document is not defined for XML. Set it by Lutaml::Xml::Parsers::Xml.set_document(base_document) method"
            raise StandardError, msg
          end

          doc = File.read(@file)
          @@document.from_xml(doc)
        end
      end
    end
  end
end
