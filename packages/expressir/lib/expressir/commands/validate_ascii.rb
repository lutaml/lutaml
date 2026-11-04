# frozen_string_literal: true

require "paint"
require "table_tennis"

module Expressir
  module Commands
    class ValidateAscii < Base
      def run(express_file_path) # rubocop:disable Metrics/AbcSize
        # Check if input is a manifest file
        if File.file?(express_file_path) && File.extname(express_file_path) == ".yaml"
          validate_from_manifest(express_file_path)
          return
        end

        # Original file/directory validation logic
        if File.file?(express_file_path)
          unless File.exist?(express_file_path)
            raise Errno::ENOENT, "Specified EXPRESS file " \
                                 "`#{express_file_path}` not found."
          end

          if File.extname(express_file_path) != ".exp"
            raise ArgumentError, "Specified file `#{express_file_path}` is " \
                                 "not an EXPRESS file."
          end

          exp_files = [express_file_path]
        elsif options[:recursive]
          # Support the relative path with glob pattern
          base_path = File.expand_path(express_file_path)
          exp_files = Dir.glob("#{base_path}/**/*.exp")
        else
          # Non-recursive option
          base_path = File.expand_path(express_file_path)
          exp_files = Dir.glob("#{base_path}/*.exp")
        end

        if exp_files.empty?
          raise Errno::ENOENT, "No EXPRESS files found in " \
                               "`#{express_file_path}`."
        end

        process_files(exp_files)
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
        exp_files = manifest.schemas.map(&:path).reject do |p|
          p.nil? || p.empty?
        end

        if exp_files.empty?
          raise Expressir::NoValidSchemaPathsError.new("No valid schema paths found in manifest")
        end

        say "Validating #{exp_files.size} schema(s) from manifest for ASCII compliance..." if options[:verbose]

        process_files(exp_files)
      end

      def process_files(exp_files)
        # Process all files and collect violations
        collection = NonAsciiViolationCollection.new(
          check_remarks: options[:check_remarks],
        )

        exp_files.each do |exp_file|
          collection.process_file(exp_file)
        end

        # Output results based on format
        if options[:yaml]
          require "yaml"
          puts collection.to_yaml_data.to_yaml
        else
          collection.print_text_output
          collection.print_table_output if collection.files_with_violations.positive?
        end
      end
    end
  end
end
