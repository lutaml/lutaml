module Expressir
  module Commands
    # `fix` — rewrites self-schema-qualified references (#125): string
    # literals like `'THIS_SCHEMA.ITEM'` lose the current-schema prefix
    # when the item is local, or gain the item's true defining schema
    # otherwise. Outputs the corrected EXPRESS file.
    class Fix < Base
      def run(path)
        # Load the interface closure (same-dir by default, or --manifest /
        # --stepmod) so SelfSchemaReference can resolve where each item
        # truly comes from.
        files = ParityInputs.closure_paths(
          path, manifest: options[:manifest], stepmod: options[:stepmod]
        ).select { |f| File.exist?(f) }
        repository = Expressir::Express::Parser.from_files(
          files, skip_references: true
        )
        total = repository.schemas.sum do |schema|
          Expressir::Express::SelfSchemaReference.fix!(schema)
        end

        text = Expressir::Express::Formatter.format(repository)
        if options[:output]
          File.write(options[:output], text)
          say "#{total} self-schema reference(s) fixed; written to " \
              "#{options[:output]}"
        else
          $stdout.write(text)
        end
      end
    end
  end
end
