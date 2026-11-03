# frozen_string_literal: true

module Expressir
  module Commands
    # `expressir export-json-schema`: write the JSON Schema rendering of
    # the first schema in PATH.
    class ExportJsonSchema < Base
      def run(path)
        repository = Expressir::Express::Parser.from_file(path)
        schema = repository.schemas.first
        raise Thor::Error, "no schema in #{path}" unless schema

        document = Expressir::Interop::JsonSchema.new(schema).to_json
        write(document)
      end

      private

      def write(document)
        if options[:output]
          File.write(options[:output], document)
          say "written to #{options[:output]}"
        else
          $stdout.write(document)
        end
      end
    end
  end
end
