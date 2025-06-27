# frozen_string_literal: true

require_relative "parsers/class_definition"
require_relative "parsers/class_definition_transformer"

module Lutaml
  module Lml
    class Error < StandardError; end

    # The main entry point for parsing LML documents
    def self.parse(input)
      parsed = Parsers::ClassDefinition.parse(input)
      transform(parsed)
    rescue Parslet::ParseFailed => e
      raise Error, "LML Parsing Error: #{e.message}"
    end

    # Transform the parsed document into a different format
    def self.transform(document)
      Parsers::ClassDefinitionTransform.new.apply(document)
    end
  end
end
