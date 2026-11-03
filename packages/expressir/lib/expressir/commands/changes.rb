# frozen_string_literal: true

require "thor"

module Expressir
  module Commands
    # Thor subcommand for EXPRESS Changes file operations
    class Changes < Thor
      desc "validate PATH", "Validate EXPRESS Changes YAML file"
      method_option :normalize, type: :boolean,
                                desc: "Normalize file through round-trip serialization"
      method_option :in_place, type: :boolean,
                               desc: "Update file in place (requires --normalize)"
      method_option :output, type: :string,
                             desc: "Output file path (for normalized output)"
      method_option :verbose, type: :boolean,
                              desc: "Show verbose output"
      def validate(path)
        ChangesValidate.new(options).run(path)
      end

      desc "import-eengine INPUT_XML SCHEMA_NAME VERSION",
           "Import eengine comparison XML to EXPRESS Changes YAML"
      method_option :output, type: :string, aliases: "-o",
                             desc: "Output YAML file path (stdout if not specified)"
      method_option :verbose, type: :boolean,
                              desc: "Show verbose output"
      def import_eengine(input_xml, schema_name, version)
        ChangesImportEengine.call(input_xml, options[:output], schema_name,
                                  version, **options)
      end
    end
  end
end
