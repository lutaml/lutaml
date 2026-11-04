# frozen_string_literal: true

module Expressir
  module Commands
    class ValidateLoad < Base
      def run(paths)
        # Determine if input is a manifest or direct paths
        if paths.size == 1 && File.extname(paths.first) == ".yaml"
          validate_from_manifest(paths.first)
        else
          validate_from_paths(paths)
        end
      end

      private

      def validate_from_manifest(manifest_path)
        unless File.exist?(manifest_path)
          raise Expressir::ManifestNotFoundError.new(manifest_path)
        end

        say "Loading manifest: #{manifest_path}..." if options[:verbose]

        # Load manifest
        manifest = Expressir::SchemaManifest.from_file(manifest_path)

        # Extract paths from manifest
        paths = manifest.schemas.map(&:path).reject { |p| p.nil? || p.empty? }

        if paths.empty?
          raise Expressir::NoValidSchemaPathsError.new("No valid schema paths found in manifest")
        end

        say "Validating #{paths.size} schema(s) from manifest..." if options[:verbose]

        validate_from_paths(paths)
      end

      def validate_from_paths(paths)
        no_version = []
        no_valid = []

        # The parses fan out across forked workers (issue #584); the
        # reporting stays on the main thread, in input order. Small
        # sets stay sequential (the facility's own threshold).
        parse = ->(path) do
          Expressir::Express::Parser.from_file(path)
        rescue StandardError
          nil
        end
        results =
          if Expressir::Express::ParallelFiles.sequential?(paths, jobs_count)
            paths.map { |path| parse.call(path) }
          else
            Expressir::Express::ParallelFiles.run(
              paths, parse: parse, max_processes: jobs_count
            )
          end

        paths.zip(results).each do |path, repository|
          x = Pathname.new(path).realpath.relative_path_from(Dir.pwd)
          say "Validating #{x}"

          if repository.nil?
            no_valid << "Failed to parse: #{x}"
            next
          end

          repository.schemas.each do |schema|
            unless schema.version&.value
              no_version << "Missing version string: schema `#{schema.id}` | #{x}"
            end
          end
        end

        print_validation_errors(:failed_to_parse, no_valid)
        print_validation_errors(:missing_version_string, no_version)

        unless [no_valid, no_version].all?(&:empty?)
          raise Expressir::SchemaValidationError.new(
            "Schema validation failed",
            errors: no_valid + no_version,
          )
        end

        say "Validation passed for all EXPRESS schemas."
      end

      def print_validation_errors(type, array)
        return if array.empty?

        say "#{'*' * 20} RESULTS: #{type.to_s.upcase.tr('_', ' ')} #{'*' * 20}"
        array.each do |msg|
          say msg
        end
      end
    end
  end
end
