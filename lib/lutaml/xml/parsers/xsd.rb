# frozen_string_literal: true

module Lutaml
  module Xml
    module Parsers
      # Parses XSD schema files into Lutaml::Xml::Schema::Xsd::Schema objects.
      #
      # Delegates to lutaml-model's XSD parser with lazy loading to avoid
      # eager-loading ~50 XSD model classes when not parsing XSD.
      #
      # @example Parse an XSD file
      #   schema = Lutaml::Xml::Parsers::Xsd.parse(File.new("schema.xsd"))
      #
      # @example With location for resolving imports
      #   schema = Lutaml::Xml::Parsers::Xsd.parse(
      #     File.new("schema.xsd"),
      #     location: "/path/to/schemas",
      #   )
      class Xsd
        # @param file [File, IO] file object with XSD content
        # @param options [Hash] parsing options
        # @option options [String] :location base path for resolving schema imports
        # @return [Lutaml::Xml::Schema::Xsd::Schema]
        def self.parse(file, options = {})
          require "lutaml/xml/schema/xsd"

          Lutaml::Xml::Schema::Xsd.parse(
            file.read,
            location: options[:location],
          )
        end
      end
    end
  end
end
