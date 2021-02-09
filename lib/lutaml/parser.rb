require "lutaml/express"
require "lutaml/uml"
require "lutaml/uml/lutaml_path/document_wrapper"
require "lutaml/express/lutaml_path/document_wrapper"

module Lutaml
  class Parser
    attr_reader :parse_type, :file

    class << self
      def parse(file, input_type = nil)
        new(file, input_type).parse
      end

      def parse_into_document(file, input_type = nil)
        new(file, input_type).parse_into_document
      end
    end

    def initialize(file, input_type)
      @parse_type = input_type ? input_type : File.extname(file.path)[1..-1]
      @file = file
    end

    def parse
      document = parse_into_document
      document_wrapper(document)
    end

    def parse_into_document
      case parse_type
      when "exp"
        Lutaml::Express::Parsers::Exp.parse(file)
      when "lutaml"
        Lutaml::Uml::Parsers::Dsl.parse(file)
      when "yml"
        Lutaml::Uml::Parsers::Yaml.parse(file.path)
      else
        raise ArgumentError, "Unsupported file format"
      end
    end

    private

    def document_wrapper(document)
      if parse_type == "exp"
        return Lutaml::Express::LutamlPath::DocumentWrapper.new(document)
      end

      Lutaml::Uml::LutamlPath::DocumentWrapper.new(document)
    end
  end
end
