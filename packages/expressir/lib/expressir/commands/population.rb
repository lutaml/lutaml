# frozen_string_literal: true

require "json"
require "thor"

module Expressir
  module Commands
    # `expressir population validate|diff` (TODO.instance/03):
    # manifest-driven dataset validation with a deterministic receipt,
    # and instance-level comparison of two populations.
    class Population < Thor
      desc "validate MANIFEST", "Validate the dataset and write a receipt"
      method_option :output, type: :string, aliases: "-o",
                             desc: "Receipt path (defaults to stdout)"
      def validate(manifest_path)
        manifest = Expressir::P21::DatasetManifest.from_file(manifest_path)
        schema = Expressir::Express::Parser.from_file(manifest.schema_path)
          .schemas.first

        results = {}
        manifest.file_paths.each do |path|
          population = Expressir::P21::Parser.parse(File.read(path))
          results[path] = Expressir::P21::Validator.validate(
            population, schema, short_names: manifest.short_name_map
          )
        end

        receipt = Expressir::P21::Receipt.build(manifest, results)
        if options[:output]
          File.write(options[:output], receipt)
          say "receipt written to #{options[:output]}"
        else
          $stdout.write(receipt)
        end

        errors = JSON.parse(receipt)["summary"]["errors"]
        return if errors.zero?

        raise Thor::Error, "dataset validation produced #{errors} error(s)"
      end

      desc "diff FILE_A FILE_B", "Compare two Part 21 populations by instance"
      def diff(path_a, path_b)
        base = Expressir::P21::Parser.parse(File.read(path_a))
        revised = Expressir::P21::Parser.parse(File.read(path_b))
        deltas = Expressir::P21::Diff.diff(base, revised)
        say "added:   #{deltas[:added].join(' ')}"
        say "removed: #{deltas[:removed].join(' ')}"
        say "changed: #{deltas[:changed].join(' ')}"
      end

      def self.exit_on_failure?
        true
      end

      private

      def say(message)
        $stdout.puts(message)
      end
    end
  end
end
