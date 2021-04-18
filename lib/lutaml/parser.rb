require "lutaml/express"
require "lutaml/uml"
require "lutaml/xmi"
require "lutaml/uml/lutaml_path/document_wrapper"
require "lutaml/express/lutaml_path/document_wrapper"
require "expressir/express/cache"

module Lutaml
  class Parser
    EXPRESS_CACHE_PARSE_TYPE = "exp.cache".freeze

    attr_reader :parse_type, :file_list

    class << self
      def parse(file_list, input_type = nil)
        file_list = file_list.is_a?(Array) ? file_list : [file_list]
        new(Array(file_list), input_type).parse
      end

      def parse_into_document(file_list, input_type = nil)
        file_list = file_list.is_a?(Array) ? file_list : [file_list]
        new(Array(file_list), input_type).parse_into_document
      end
    end

    def initialize(file_list, input_type)
      @parse_type = input_type ? input_type : File.extname(file_list.first.path)[1..-1]
      @file_list = file_list
    end

    def parse
      documents = parse_into_document
      return document_wrapper(documents) if ["exp", EXPRESS_CACHE_PARSE_TYPE].include?(parse_type)

      documents.map { |doc| document_wrapper(doc) }
    end

    def parse_into_document
      case parse_type
      when "exp"
        Expressir::Express::Parser.from_files(file_list.map(&:path))
      when EXPRESS_CACHE_PARSE_TYPE
        Expressir::Express::Cache.from_file(file_list.first.path)
      when 'xmi'
        file_list.map { |file| Lutaml::XMI::Parsers::XML.parse(file) }
      when "lutaml"
        file_list.map { |file| Lutaml::Uml::Parsers::Dsl.parse(file) }
      when "yml"
        file_list.map { |file| Lutaml::Uml::Parsers::Yaml.parse(file.path) }
      else
        raise ArgumentError, "Unsupported file format"
      end
    end

    private

    def document_wrapper(document)
      if ["exp", EXPRESS_CACHE_PARSE_TYPE].include?(parse_type)
        return Lutaml::Express::LutamlPath::DocumentWrapper.new(document)
      end

      Lutaml::Uml::LutamlPath::DocumentWrapper.new(document)
    end
  end
end
