module Expressir
  module Commands
    class Clean < Base
      def run(path)
        repository = Expressir::Express::Parser.from_file(path)
        formatted_schemas = repository.schemas.map do |schema|
          # Format schema without remarks
          schema.format(no_remarks: true)
        end.join("\n\n")

        if options[:output]
          File.write(options[:output], formatted_schemas)
          say "Cleaned schema written to #{options[:output]}"
        else
          say formatted_schemas
        end
      end
    end
  end
end
