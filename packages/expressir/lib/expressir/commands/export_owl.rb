# frozen_string_literal: true

module Expressir
  module Commands
    # `expressir export-owl`: write the OWL/Turtle rendering of the
    # first schema in PATH.
    class ExportOwl < Base
      def run(path)
        repository = Expressir::Express::Parser.from_file(path)
        schema = repository.schemas.first
        raise Thor::Error, "no schema in #{path}" unless schema

        document = Expressir::Interop::Owl.new(
          schema,
          base_iri: options[:base_iri],
        ).export
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
