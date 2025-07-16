require "lutaml/express"
require "lutaml/uml"
require "lutaml/xmi"
require "lutaml/xml"
require "expressir/express/cache"

module Lutaml
  class Parser
    EXPRESS_CACHE_PARSE_TYPE = "exp.cache".freeze

    attr_reader :parse_type, :file_list

    class << self
      def parse(file_list, input_type = nil, options: {})
        file_list = [file_list] unless file_list.is_a?(Array)
        new(Array(file_list), input_type, options).parse_into_document
      end
      alias_method :parse_into_document, :parse
    end

    def initialize(file_list, input_type, options = {})
      @parse_type = input_type || File.extname(file_list.first.path)[1..-1]
      @file_list = file_list
      @options = options
    end

    def parse_into_document # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
      case parse_type
      when "exp"
        Expressir::Express::Parser.from_files(file_list.map(&:path))
      when EXPRESS_CACHE_PARSE_TYPE
        Expressir::Express::Cache.from_file(file_list.first.path)
      when "xmi"
        file_list.map { |file| Lutaml::XMI::Parsers::XML.parse(file) }
      when "xml"
        file_list.map { |file| Lutaml::Xml::Parsers::Xml.parse(file) }
      when "lutaml"
        file_list.map { |file| Lutaml::Uml::Parsers::Dsl.parse(file) }
      when "yml", "yaml"
        file_list.map { |file| Lutaml::Uml::Parsers::Yaml.parse(file.path) }
      when "xsd"
        Lutaml::Xsd.parse(
          # multiple files are not expected and handled for XSD only.
          file_list.first.read,
          # string keys are expected only (e.g., "location")
          location: @options["location"],
        )
      else
        raise ArgumentError, "Unsupported file format"
      end
    end
  end
end
