module Expressir
  module Commands
    # `expand` — flattens an interface closure into a single concatenated
    # .exp artifact (expressir#247). Equivalent to eeng's
    # `--concat_schema` over the root schema's closure.
    class Expand < Base
      def run(path)
        root, repository = ParityInputs.root_schema(
          path, manifest: options[:manifest], stepmod: options[:stepmod]
        )
        exit_with_error "schema for #{path} not found in closure" unless root

        closure = Expressir::Express::Concatenator.closure(root, repository)

        if options[:output]
          File.open(options[:output], "w") do |io|
            Expressir::Express::Concatenator.write(io, closure)
          end
          say "Concatenated schema written to #{options[:output]}"
        else
          Expressir::Express::Concatenator.write($stdout, closure)
        end
      end
    end
  end
end
