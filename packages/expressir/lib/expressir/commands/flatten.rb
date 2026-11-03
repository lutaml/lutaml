module Expressir
  module Commands
    # `flatten` — converts a STEPmod-style multi-schema root into a single
    # ISO 10303-11:1994 longform schema (SHTOLO, expressir#32).
    # Equivalent to eeng's `--flat -mode _longform`.
    class Flatten < Base
      def run(path)
        root, repository = ParityInputs.root_schema(
          path, manifest: options[:manifest], stepmod: options[:stepmod]
        )
        exit_with_error "schema for #{path} not found in closure" unless root

        longform_name = options[:longform_name] || "#{root.id}_lf"
        extenders = options[:extenders] == "none" ? :none : :all
        flat = Expressir::Express::Shtolo.new(root, repository,
                                              longform_name: longform_name,
                                              extenders: extenders).flatten.schema
        text = Expressir::Express::Formatter.format(flat)

        if options[:output]
          File.write(options[:output], text)
          say "Longform schema written to #{options[:output]}"
        else
          $stdout.write(text)
        end
      end
    end
  end
end
