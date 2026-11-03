require "table_tennis"
require "json"
require "yaml"
require "ruby-progressbar"

module Expressir
  module Commands
    class Coverage < Base
      def run(paths)
        if paths.empty?
          exit_with_error "No paths specified. Please provide paths to EXPRESS files or directories."
        end

        reports = collect_reports(paths)

        if reports.empty?
          exit_with_error "No valid EXPRESS files were processed. Nothing to report."
        end

        # Generate output based on format
        case options[:format].downcase
        when "json"
          display_json_output(reports)
        when "yaml"
          display_yaml_output(reports)
        else # Default to text
          display_text_output(reports)
        end
      end

      private

      def collect_reports(paths)
        reports = []
        ignored_files = parse_ignore_files

        paths.each do |path|
          handle_path(path, reports, ignored_files)
        end

        reports
      end

      def handle_path(path, reports, ignored_files)
        if File.directory?(path)
          handle_directory(path, reports, ignored_files)
        elsif File.extname(path).downcase == ".exp"
          handle_express_file(path, reports, ignored_files)
        elsif [".yml", ".yaml"].include?(File.extname(path).downcase)
          handle_schema_manifest(path, reports, ignored_files)
        else
          say "Unsupported file type: #{path}"
        end
      end

      def handle_directory(path, reports, ignored_files)
        say "Processing directory: #{path}"
        exp_files = Dir.glob(File.join(path, "**", "*.exp"))
        if exp_files.empty?
          say "No EXPRESS files found in directory: #{path}"
          return
        end

        say "Found #{exp_files.size} EXPRESS files to process"

        # Initialize progress bar for directory files
        progress = ProgressBar.create(
          title: "Processing files",
          total: exp_files.size,
          format: "%t: [%B] %p%% %a [%c/%C] %e",
          output: $stdout,
        )

        # Parse all files and create a repository with progress tracking
        begin
          repository = Expressir::Express::Parser.from_files(
            exp_files, max_processes: options[:max_processes]
          ) do |filename, _schemas, error|
            if error
              say "  Error processing #{File.basename(filename)}: #{error.message}"
            end
            progress.increment
          end
          skip_types = parse_skip_types
          report = Expressir::Coverage::Report.from_repository(
            repository,
            skip_types,
            ignored_files,
          )
          reports << report
        rescue StandardError => e
          say "Error processing directory #{path}: #{e.message}"
        end
      end

      def handle_express_file(path, reports, ignored_files)
        say "Processing file: #{path}"
        begin
          # For a single file, we don't need a progress bar
          skip_types = parse_skip_types
          report = Expressir::Coverage::Report.from_file(path, skip_types,
                                                         ignored_files)
          reports << report
        rescue StandardError => e
          say "Error processing file #{path}: #{e.message}"
        end
      end

      def handle_schema_manifest(path, reports, ignored_files)
        say "Processing schema manifest: #{path}"
        begin
          # Load schema manifest
          manifest = Expressir::SchemaManifest.from_file(path)
          schema_files = manifest.schemas.map(&:path)

          say "Found #{schema_files.size} schema files to process"

          # Initialize progress bar
          if schema_files && !schema_files.empty?
            say "Processing schemas from manifest file"

            progress = ProgressBar.create(
              title: "Processing schemas",
              total: schema_files.size,
              format: "%t: [%B] %p%% %a [%c/%C] %e",
              output: $stdout,
            )

            # Process files with progress tracking
            repository = Expressir::Express::Parser.from_files(
              schema_files, max_processes: options[:max_processes]
            ) do |filename, _schemas, error|
              if error
                say "  Error processing #{File.basename(filename)}: #{error.message}"
              end
              progress.increment
            end

            # Create and add the report
            skip_types = parse_skip_types
            report = Expressir::Coverage::Report.from_repository(
              repository,
              skip_types,
              ignored_files,
            )
            reports << report
          end
        rescue StandardError => e
          say "Error processing schema manifest #{path}: #{e.message}"
        end
      end

      def display_text_output(reports)
        say "\nEXPRESS Documentation Coverage"
        say "=============================="

        # If multiple reports, display directory coverage first
        if reports.size > 1
          display_directory_coverage(reports)
        end

        display_file_coverage(reports)
        display_overall_stats(reports)
      end

      def display_directory_coverage(reports)
        say "\nDirectory Coverage:"

        # Collect directory data from all reports
        dirs = {}
        reports.each do |report|
          report.directory_reports.each do |dir_report|
            dir = dir_report["directory"]
            dirs[dir] ||= { "total" => 0, "documented" => 0 }
            dirs[dir]["total"] += dir_report["total"]
            dirs[dir]["documented"] += dir_report["documented"]
          end
        end

        table_data = []
        dirs.each do |dir, stats|
          coverage = stats["total"].positive? ? (stats["documented"].to_f / stats["total"] * 100).round(2) : 100.0
          table_data << {
            directory: dir,
            total: stats["total"].to_s,
            documented: stats["documented"].to_s,
            coverage_percentage: "#{coverage}%",
          }
        end

        table = TableTennis.new(
          table_data,
          {
            title: "Entity coverage per directory",
            headers: {
              file: "Directory",
              total: "Total Entities",
              documented: "Documented Entities",
              coverage_percentage: "Coverage %",
            },
            titleize: true,
            layout: true,
          },
        )

        say table
      end

      def display_file_coverage(reports)
        # Prepare data for table_tennis
        table_data = []
        reports.each do |report|
          report.file_reports.each do |file_report|
            file_path = file_report["file"]

            # Format undocumented entities as "TYPE name, TYPE name, ..."
            undocumented = file_report["undocumented"].map do |entity_info|
              "#{entity_info['type']} #{entity_info['name']}"
            end.join(", ")

            coverage = file_report["coverage"].round(2)

            table_data << {
              filename: File.basename(file_path),
              undocumented_entities: if undocumented.empty?
                                       "None"
                                     else
                                       undocumented
                                     end,
              coverage_percentage: "#{coverage}%",
            }
          end
        end

        table = TableTennis.new(
          table_data,
          {
            title: "Entity coverage in file",
            headers: {
              filename: "Filename",
              undocumented_entities: "Undocumented Entities",
              coverage_percentage: "Coverage %",
            },
            titleize: true,
            layout: {
              filename: 30,
              undocumented_entities: 50,
              coverage_percentage: 20,
            },
          },
        )

        say table
      end

      def display_overall_stats(reports)
        # Get structured report for overall statistics
        overall = build_structured_report(reports)["overall"]

        coverage_percentage = overall["coverage_percentage"]
        table_data = [
          {
            metric: "Coverage Percentage",
            value: "#{coverage_percentage}%",
          },
          {
            metric: "Total Entities",
            value: overall["total_entities"].to_s,
          },
          {
            metric: "Documented Entities",
            value: overall["documented_entities"].to_s,
          },
          {
            metric: "Undocumented Entities",
            value: overall["undocumented_entities"].to_s,
          },
        ]

        table = TableTennis.new(
          table_data,
          {
            title: "Entity overall coverage",
            titleize: true,
            layout: true,
          },
        )

        say table
      end

      def build_structured_report(reports)
        # Calculate ignored file statistics
        ignored_files = reports.flat_map(&:ignored_file_reports)
        ignored_entities_count = ignored_files.sum { |f| f["total"] }

        total = reports.sum { |r| r.total_entities.size }
        documented = reports.sum { |r| r.documented_entities.size }

        coverage_per = if total.positive?
                         (documented.to_f / total * 100).round(2)
                       else
                         100.0
                       end

        overall_stats = {
          "total_entities" => reports.sum { |r| r.total_entities.size },
          "documented_entities" => reports.sum do |r|
            r.documented_entities.size
          end,
          "undocumented_entities" => reports.sum do |r|
            r.undocumented_entities.size
          end,
          "coverage_percentage" => coverage_per,
        }

        # Add ignored file information if there are any
        if ignored_files.any?
          overall_stats["ignored_files_count"] = ignored_files.size
          overall_stats["ignored_entities_count"] = ignored_entities_count
        end

        structured_report = {
          "overall" => overall_stats,
          "files" => reports.flat_map(&:file_reports),
          "directories" => reports.flat_map(&:directory_reports),
        }

        # Add ignored files section if there are any
        if ignored_files.any?
          structured_report["ignored_files"] = ignored_files
        end

        structured_report
      end

      def display_json_output(reports)
        output_file = options[:output] || "coverage_report.json"
        File.write(output_file,
                   JSON.pretty_generate(build_structured_report(reports)))
        say "JSON coverage report written to: #{output_file}"
      end

      def display_yaml_output(reports)
        output_file = options[:output] || "coverage_report.yaml"
        File.write(output_file, build_structured_report(reports).to_yaml)
        say "YAML coverage report written to: #{output_file}"
      end

      # Parse and validate the skip_types option
      # @return [Array<String>] Array of validated entity type names
      def parse_skip_types
        skip_types_option = options["exclude"] || options[:exclude]
        return [] unless skip_types_option

        # Handle both string (comma-separated) and array inputs
        requested_types = if skip_types_option.is_a?(Array)
                            skip_types_option.map(&:to_s).map(&:strip).map(&:upcase)
                          else
                            skip_types_option.split(",").map(&:strip).map(&:upcase)
                          end

        # Validate each type (supports both TYPE and TYPE:SUBTYPE formats)
        requested_types.each do |type|
          validate_skip_type(type)
        end

        requested_types
      end

      # Validate a single skip type (supports TYPE:SUBTYPE and FUNCTION:SUBTYPE syntax)
      # @param type [String] The type to validate
      def validate_skip_type(type)
        if type.include?(":")
          # Handle TYPE:SUBTYPE and FUNCTION:SUBTYPE format
          main_type, subtype = type.split(":", 2)

          # Validate main type
          unless Expressir::Coverage::ENTITY_TYPE_MAP.key?(main_type)
            exit_with_error "Invalid entity type: #{main_type}. " \
                            "Valid types are: #{Expressir::Coverage::ENTITY_TYPE_MAP.keys.join(', ')}"
          end

          # For TYPE, validate subtype
          if main_type == "TYPE"
            unless Expressir::Coverage::TYPE_SUBTYPES.include?(subtype)
              exit_with_error "Invalid TYPE subtype: #{subtype}. " \
                              "Valid TYPE subtypes are: #{Expressir::Coverage::TYPE_SUBTYPES.join(', ')}"
            end
          # For FUNCTION, validate subtype
          elsif main_type == "FUNCTION"
            unless subtype == "INNER"
              exit_with_error "Invalid FUNCTION subtype: #{subtype}. " \
                              "Valid FUNCTION subtypes are: INNER"
            end
          else
            exit_with_error "Subtype syntax (#{type}) is only supported for TYPE and FUNCTION entities"
          end
        else
          # Handle simple type format
          unless Expressir::Coverage::ENTITY_TYPE_MAP.key?(type)
            exit_with_error "Invalid entity type: #{type}. " \
                            "Valid types are: #{Expressir::Coverage::ENTITY_TYPE_MAP.keys.join(', ')}"
          end
        end
      end

      # Parse and expand ignore files from YAML
      # @return [Hash] Hash mapping absolute file paths to their matched patterns
      def parse_ignore_files
        ignore_files_option = options["ignore_files"] || options[:ignore_files]
        return {} unless ignore_files_option

        unless File.exist?(ignore_files_option)
          say "Warning: Ignore files YAML not found: #{ignore_files_option}"
          return {}
        end

        begin
          patterns = YAML.load_file(ignore_files_option)
          unless patterns.is_a?(Array)
            say "Warning: Invalid ignore files YAML format. Expected an array of file patterns."
            return {}
          end

          ignore_files_dir = File.dirname(File.expand_path(ignore_files_option))
          expanded_files = {}

          patterns.each do |pattern|
            # Resolve pattern relative to the YAML file's directory
            full_pattern = File.expand_path(pattern, ignore_files_dir)

            # Expand glob pattern
            matched_files = Dir.glob(full_pattern)

            if matched_files.empty?
              say "Warning: No files matched pattern: #{pattern}"
            else
              matched_files.each do |file_path|
                # Store absolute path and the original pattern that matched it
                expanded_files[File.expand_path(file_path)] = pattern
              end
            end
          end

          if expanded_files.any?
            say "Found #{expanded_files.size} files to ignore from patterns"
          end

          expanded_files
        rescue StandardError => e
          say "Warning: Error processing ignore files YAML #{ignore_files_option}: #{e.message}"
          {}
        end
      end
    end
  end
end
