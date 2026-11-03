# frozen_string_literal: true

require "thor"

module Expressir
  module Commands
    # `expressir receipt MANIFEST` (TODO.compat/04): run the three
    # shipped validators over one workspace manifest and emit the
    # unified receipt — deterministic canonical JSON, structured for
    # signing. Exits 1 when the receipt reports errors.
    class Receipt < Base
      def run(manifest_path)
        manifest = Expressir::Receipt::WorkspaceManifest.from_file(manifest_path)
        receipt = Expressir::Receipt.generate(Expressir::Receipt.build(manifest))
        if options[:output]
          File.write(options[:output], receipt)
          say "receipt written to #{options[:output]}"
        else
          $stdout.write(receipt)
        end

        summary = JSON.parse(receipt)["summary"]
        return if summary["valid"]

        raise Thor::Error,
              "repository receipt reports #{summary['errors']} error(s)"
      end
    end
  end
end
