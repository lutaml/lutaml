# frozen_string_literal: true

module Expressir
  module Commands
    # `expressir xsd` (#276): write the XML Schema rendering of the
    # schema at PATH.
    class Xsd < Base
      def run(path)
        repo = Expressir::Express::Parser.from_file(path)
        schema = repo.schemas.first
        raise Thor::Error, "no schema in #{path}" unless schema

        xml = Expressir::Express::Xsd.format(schema)
        if options[:output]
          File.write(options[:output], xml)
          say "written to #{options[:output]}"
        else
          $stdout.write(xml)
        end
      end
    end
  end
end
