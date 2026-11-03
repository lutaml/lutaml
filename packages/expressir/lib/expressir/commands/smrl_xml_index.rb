# frozen_string_literal: true

require "thor"

module Expressir
  module Commands
    # `expressir xml-index` (#276): write the SMRL index XML for a
    # repository — one <schema> element per schema, the data layer of
    # the STEP Module Resource Library document set.
    class SmrlXmlIndex < Base
      def run(path)
        repo = Expressir::Express::Parser.from_files(Dir.glob(File.join(path, "**", "*.exp")), skip_references: true)
        raise Thor::Error, "no schemas under #{path}" if repo.schemas.empty?

        xml = Expressir::Express::SmrlXml.format(repo)
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
