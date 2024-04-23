require "nokogiri"
require "htmlentities"
require "lutaml/uml/has_attributes"
require "lutaml/uml/document"

require "shale/schema"

module Lutaml
  module Xml
    module Parsers
      # Class for parsing .xml schema files into ::Lutaml::Uml::Document
      class Xml
        def self.load_schema(schema, root_schema)
          result = Shale::Schema.from_xml([schema])

          result.values.each do |klass|
            # Temporary solution will update in the parser
            klass = klass.gsub(/^require.*?\n/, "")
            klass = klass.gsub(/< Shale::Mapper/, "< Lutaml::Xml::Mapper")

            eval(klass, TOPLEVEL_BINDING)
          end

          @@root_schema = root_schema
        end

        def self.parse(file)
          new(file, @@root_schema).parse
        end

        def initialize(file, root_schema)
          @file = file
          @root_schema = root_schema
          @root_class = Object.const_get(root_schema)
        end

        def parse
          doc = File.read(@file)

          @root_class.from_xml(doc)
        end

        private

        def load_schema(schema)
          result = Shale::Schema.from_xml([schema])

          result.values.each do |klass|
            klass = klass.gsub(/^require.*?\n/, "")

            eval(klass, TOPLEVEL_BINDING)
          end
        end
      end
    end
  end
end
