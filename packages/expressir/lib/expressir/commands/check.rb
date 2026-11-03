require "json"

module Expressir
  module Commands
    # `validate check` — semantic checks modeled on eeng check-p11 note
    # subset (expressir#282). Exits 1 when any :error notes are emitted.
    # Loads the interface closure of each input file so USE FROM targets
    # are visible — matches Concatenator/Shtolo expectations.
    class Check < Base
      def run(*paths)
        files = Array(paths).flat_map do |p|
          if File.directory?(p)
            Dir["#{p}/**/*.exp"]
          else
            ParityInputs.closure_paths(
              p, manifest: options[:manifest], stepmod: options[:stepmod]
            ).select { |f| File.exist?(f) }
          end
        end.uniq
        repository = Expressir::Express::Parser.from_files(files)
        # A file that failed to parse is a nil entry: it must fail the run,
        # not pass silently as a "clean" schema (#413).
        failed = repository.files.count(&:nil?)
        if failed.positive?
          raise Thor::Error, "#{failed} file(s) failed to parse"
        end

        result = Expressir::Express::Checker.new(
          repository, dialect: options[:dialect]
        ).check

        if options[:json]
          say JSON.generate(
            valid: result.valid?,
            errors: serialize(result.errors),
            warnings: serialize(result.warnings),
          )
        else
          result.notes.each { |n| say "[#{n.severity}] #{n.id}: #{n.message}" }
          say "#{result.errors.size} error(s), #{result.warnings.size} warning(s)"
        end

        return if result.valid?

        raise Thor::Error, "schema check produced #{result.errors.size} error(s)"
      end

      private

      def serialize(notes)
        notes.map do |n|
          { id: n.id.to_s, severity: n.severity.to_s, schema: n.schema,
            message: n.message }
        end
      end
    end
  end
end
