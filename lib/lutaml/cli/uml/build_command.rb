# frozen_string_literal: true

require_relative "../output_formatter"
require_relative "../../uml_repository"
require_relative "../../uml_repository/package_metadata"

module Lutaml
  module Cli
    module Uml
      # BuildCommand builds LUR packages from XMI or QEA files
      class BuildCommand
        attr_reader :options

        def initialize(options = {})
          @options = options.transform_keys(&:to_sym)
        end

        def self.add_options_to(thor_class, _method_name) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          thor_class.long_desc <<-DESC
          Build a LUR (LutaML UML Repository) package from an XMI or QEA source file.

          The file format is auto-detected from the extension:
          - .xmi files are parsed as XMI
          - .qea files are parsed as QEA (Enterprise Architect)

          If --output is not specified, the output filename will be the input filename
          with the extension changed to .lur

          Examples:
            lutaml uml build model.xmi -o model.lur

            lutaml uml build project.qea -o project.lur --validate

            lutaml uml build model.qea     # Creates model.lur

            # With metadata
            lutaml uml build model.xmi --name "Urban Model" --version "2.0" \\
              --publisher "City Planning" --license "CC-BY-4.0"

            # Load metadata from file
            lutaml uml build model.xmi --metadata-file package-info.yaml
          DESC

          thor_class.option :output, aliases: "-o", type: :string,
                                     desc: "Output .lur file path " \
                                           "(default: input file with .lur " \
                                           "extension)"

          # Package metadata options
          thor_class.option :name, type: :string, desc: "Package name"
          thor_class.option :version, type: :string, default: "1.0",
                                      desc: "Package version"
          thor_class.option :publisher, type: :string,
                                        desc: "Publisher or organization name"
          thor_class.option :license, type: :string,
                                      desc: "License identifier " \
                                            "(e.g., MIT, CC-BY-4.0)"
          thor_class.option :description, type: :string,
                                          desc: "Package description"
          thor_class.option :homepage, type: :string, desc: "Homepage URL"
          thor_class.option :keywords, type: :string,
                                       desc: "Comma-separated keywords"
          thor_class.option :authors, type: :array,
                                      desc: "Author names (can be specified " \
                                            "multiple times)"
          thor_class.option :maintainers, type: :string,
                                          desc: "Maintainer contact information"
          thor_class.option :metadata_file, type: :string,
                                            desc: "Load metadata from YAML file"

          # Build options
          thor_class.option :format, type: :string, default: "yaml",
                                     desc: "Serialization format (yaml)"
          thor_class.option :validate, type: :boolean, default: true,
                                       desc: "Validate before building"
          thor_class.option :strict, type: :boolean, default: false,
                                     desc: "Fail build on validation errors"
          thor_class.option :show_warnings, type: :boolean, default: true,
                                            desc: "Show validation warnings"
          thor_class.option :limit_errors, type: :numeric, default: nil,
                                           desc: "Limit validation errors " \
                                                 "shown (default: all " \
                                                 "if <100, else 50)"
          thor_class.option :validation_format, type: :string, default: "text",
                                                desc: "Validation output " \
                                                      "format (text|json)"
          thor_class.option :quick, type: :boolean, default: false,
                                    desc: "Quick mode: build + validate + stats"
          thor_class.option :verbose, type: :boolean, default: false,
                                      desc: "Show detailed type resolution " \
                                            "for each attribute"
        end

        def run(model_path) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          unless File.exist?(model_path)
            puts OutputFormatter.error("Model file not found: #{model_path}")
            raise Thor::Error, "Model file not found: #{model_path}"
          end

          # Set default output path if not provided
          output_path = options[:output] || model_path.sub(/\.(xmi|qea)$/i,
                                                           ".lur")

          # Detect file type
          is_qea = model_path.end_with?(".qea")
          file_type = is_qea ? "QEA" : "XMI"

          # Parse with validation for QEA files
          repo, qea_validation_result = if is_qea
                                          require_relative "../../qea"
                                          parse_qea_with_validation(model_path)
                                        else
                                          OutputFormatter.progress(
                                            "Parsing #{file_type} file",
                                          )
                                          r = Lutaml::UmlRepository::Repository
                                            .from_xmi(model_path)
                                          OutputFormatter.progress_done
                                          [r, nil]
                                        end

          # Display QEA validation results if available
          if qea_validation_result && options[:validate]
            display_qea_validation_result(qea_validation_result)

            if options[:strict] && qea_validation_result.has_errors?
              puts ""
              puts OutputFormatter.error(
                "Build failed due to validation errors",
              )
              raise Thor::Error, "Build failed due to validation errors"
            end
          end

          # Validate repository if requested
          # (XMI files or additional validation)
          # Strict mode forces validation even if --no-validate is passed
          if (options[:validate] || options[:strict]) && !is_qea
            OutputFormatter.progress("Validating repository")
            result = repo.validate(verbose: options[:verbose])
            OutputFormatter.progress_done

            # Display verbose validation if requested
            if options[:verbose] && result.respond_to?(:validation_details)
              display_verbose_validation(result.validation_details)
            end

            unless result.valid?
              handle_validation_result(result)

              # Display unique unresolved types if present
              if result.respond_to?(:external_references) &&
                  result.external_references.any?
                display_unresolved_types(result.external_references)
              end

              if options[:strict] && result.errors.any?
                raise Thor::Error, "Build failed due to validation errors"
              end
            end
          end

          # Build metadata from options
          metadata = build_metadata

          # Export to package with metadata
          export_options = {
            serialization_format: (
              options[:format] || options["format"] || "yaml"
            ).to_sym,
            metadata: metadata,
          }

          OutputFormatter.progress("Exporting to LUR package")
          repo.export_to_package(output_path, export_options)
          OutputFormatter.progress_done

          # Show success with statistics
          stats = repo.statistics
          puts ""
          puts OutputFormatter
            .success("Package built successfully: #{output_path}")
          puts ""
          puts "Package Metadata:"
          puts "  Name:          #{metadata.name}"
          puts "  Version:       #{metadata.version}"
          puts "  Publisher:     #{metadata.publisher}" if metadata.publisher
          puts "  License:       #{metadata.license}" if metadata.license
          puts ""
          puts "Package Contents:"
          puts "  Packages:      #{stats[:total_packages]}"
          puts "  Classes:       #{stats[:total_classes]}"
          puts "  Data Types:    #{stats[:total_data_types]}"
          puts "  Enumerations:  #{stats[:total_enums]}"
          puts "  Diagrams:      #{stats[:total_diagrams]}"
        rescue StandardError => e
          OutputFormatter.progress_done(success: false)
          puts OutputFormatter.error("Failed to build package: #{e.message}")
          puts e.backtrace.first(5).join("\n") if ENV["DEBUG"]
          raise Thor::Error, "Failed to build package: #{e.message}"
        end

        private

        def build_metadata # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          # If metadata file is provided, load from it
          if options[:metadata_file]
            return load_metadata_from_file(options[:metadata_file])
          end

          # Otherwise build from CLI options
          metadata_attrs = {
            name: options[:name] || File.basename(options[:output] || "model",
                                                  ".lur"),
            version: options[:version] || "1.0",
            serialization_format: (options[:format] || "yaml").to_s,
          }

          # Add optional fields if provided
          if options[:publisher]
            metadata_attrs[:publisher] =
              options[:publisher]
          end
          metadata_attrs[:license] = options[:license] if options[:license]
          if options[:description]
            metadata_attrs[:description] =
              options[:description]
          end
          metadata_attrs[:homepage] = options[:homepage] if options[:homepage]
          metadata_attrs[:keywords] = options[:keywords] if options[:keywords]
          if options[:authors] && !options[:authors].empty?
            metadata_attrs[:authors] =
              options[:authors]
          end
          if options[:maintainers]
            metadata_attrs[:maintainers] =
              options[:maintainers]
          end

          Lutaml::UmlRepository::PackageMetadata.new(**metadata_attrs)
        end

        def load_metadata_from_file(file_path) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          unless File.exist?(file_path)
            raise Thor::Error, "Metadata file not found: #{file_path}"
          end

          require "yaml"
          metadata_hash = YAML.load_file(file_path)

          # Override with CLI options if provided
          metadata_hash["name"] = options[:name] if options[:name]
          metadata_hash["version"] = options[:version] if options[:version]
          if options[:publisher]
            metadata_hash["publisher"] =
              options[:publisher]
          end
          metadata_hash["license"] = options[:license] if options[:license]
          if options[:description]
            metadata_hash["description"] =
              options[:description]
          end
          metadata_hash["homepage"] = options[:homepage] if options[:homepage]
          metadata_hash["keywords"] = options[:keywords] if options[:keywords]
          if options[:authors] && !options[:authors].empty?
            metadata_hash["authors"] =
              options[:authors]
          end
          if options[:maintainers]
            metadata_hash["maintainers"] =
              options[:maintainers]
          end

          # Ensure serialization_format is set
          metadata_hash["serialization_format"] ||= (
            options[:format] || "yaml"
          ).to_s

          Lutaml::UmlRepository::PackageMetadata.from_hash(metadata_hash)
        rescue Psych::SyntaxError => e
          raise Thor::Error, "Invalid YAML in metadata file: #{e.message}"
        rescue ArgumentError => e
          raise Thor::Error, "Invalid metadata: #{e.message}"
        end

        def handle_validation_result(result) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          # Determine limit: explicit option, or smart default
          limit = if options[:limit_errors]
                    options[:limit_errors]
                  elsif result.warnings.size + result.errors.size < 100
                    nil # Show all
                  else
                    50 # Show top 50
                  end

          if result.warnings.any?
            puts ""
            display_messages(
              result.warnings,
              "Validation warnings",
              :warning,
              limit,
            )
          end

          if result.errors.any?
            puts ""
            display_messages(
              result.errors,
              "Validation errors",
              :error,
              limit,
            )
          end
        end

        def display_messages(messages, title, type, limit = nil) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength
          total = messages.size
          to_show = limit ? messages.first(limit) : messages

          case type
          when :warning
            puts OutputFormatter.warning("#{title} (#{total}):")
          when :error
            puts OutputFormatter.error("#{title} (#{total}):")
          else
            puts "#{title} (#{total}):"
          end

          to_show.each { |msg| puts "  - #{msg}" }

          if limit && total > limit
            puts ""
            puts OutputFormatter.colorize(
              "  ... and #{total - limit} more #{type}s " \
              "(use --limit-errors to adjust)",
              :yellow,
            )
          end
        end

        def parse_qea_with_validation(qea_path) # rubocop:disable Metrics/MethodLength
          require_relative "../../qea"

          if options[:validate]
            puts OutputFormatter.colorize(
              "⋯ Parsing QEA file with validation...", :cyan
            )

            # Parse with validation enabled
            result = Lutaml::Qea.parse(qea_path, validate: true)

            # Result is a hash when validation is enabled
            document = result[:document]
            validation_result = result[:validation_result]
            puts " #{OutputFormatter.colorize('✓', :green)}"
            puts ""

            repo = Lutaml::UmlRepository::Repository.new(document: document)
            [repo, validation_result]
          else
            # Parse without validation (reuse existing method)
            repo = parse_qea_with_progress(qea_path)
            [repo, nil]
          end
        end

        def parse_qea_with_progress(qea_path) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          puts OutputFormatter.colorize("⋯ Parsing QEA file...", :cyan)

          # Load the database with progress tracking
          require_relative "../../qea/services/database_loader"
          loader = Lutaml::Qea::Services::DatabaseLoader.new(qea_path)

          # Track progress per table
          current_table = nil
          loader.on_progress do |table_name, current, total|
            if current_table != table_name
              current_table = table_name
              # New table started
              collection_name = format_collection_name(table_name)
              print "\r  ⋯ Loading #{collection_name}..."
              $stdout.flush
            end
            # Update progress for current table
            if current == total
              puts " #{OutputFormatter.colorize('✓', :green)} (#{total})"
            end
          end

          database = loader.load
          # Remove extra checkmark here - each table already has one

          # Transform to UML document
          print "  ⋯ Transforming to UML..."
          $stdout.flush

          require_relative "../../qea/factory/ea_to_uml_factory"
          factory = Lutaml::Qea::Factory::EaToUmlFactory.new(database)
          document = factory.create_document

          puts " #{OutputFormatter.colorize('✓', :green)}"
          puts ""

          Lutaml::UmlRepository::Repository.new(document: document)
        end

        def display_qea_validation_result(validation_result) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          return unless validation_result

          puts ""
          puts OutputFormatter.colorize("QEA Validation Results:", :cyan)
          puts ""

          if validation_result.valid?
            puts OutputFormatter.success("✓ File structure is valid")
            return
          end

          # Require formatters
          require_relative "../../qea/validation/formatters/text_formatter"
          require_relative "../../qea/validation/formatters/json_formatter"

          # Use formatter for display
          formatter_class = case options[:validation_format]
                            when "json"
                              Lutaml::Qea::Validation::Formatters::JsonFormatter
                            else
                              Lutaml::Qea::Validation::Formatters::TextFormatter
                            end

          formatter_options = {
            result: validation_result,
            limit: options[:limit_errors],
          }
          if options[:validation_format] == "text"
            formatter_options[:color] =
              true
          end

          formatter = formatter_class.new(**formatter_options)
          puts formatter.format
        end

        def display_verbose_validation(validation_details) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/PerceivedComplexity
          puts ""
          puts OutputFormatter.colorize("Detailed Type Validation:", :cyan)
          puts ""

          validation_details.each do |detail|
            class_name = detail[:class_name]
            puts OutputFormatter.colorize("Class: #{class_name}", :cyan)

            detail[:attributes].each do |attr_detail|
              attr_name = attr_detail[:attribute_name]
              type_value = attr_detail[:type_value]
              resolved_to = attr_detail[:resolved_to]
              is_valid = attr_detail[:valid]

              symbol = if is_valid
                         OutputFormatter.colorize("✓",
                                                  :green)
                       else
                         OutputFormatter.colorize(
                           "✗", :red
                         )
                       end

              puts "  #{symbol} #{attr_name}: #{type_value}"
              if resolved_to
                puts "      → #{resolved_to}"
              elsif !is_valid
                puts "      → (not found)"
              end
            end
            puts ""
          end
        end

        def display_unresolved_types(external_references) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          # Extract unique type names
          unique_types = external_references.map do |ref|
            ref[:referenced_type]
          end.uniq.sort

          return if unique_types.empty?

          puts ""
          puts OutputFormatter.colorize("Unresolved Types Summary:", :cyan)
          puts ""
          puts "Found #{unique_types.size} unique unresolved type(s):"
          puts ""
          unique_types.each { |type| puts "  - #{type}" }
          puts ""
          puts OutputFormatter.colorize(
            "To suppress these warnings, add these types to a " \
            "configuration file:", :yellow
          )
          puts ""
          puts "  # config/external_types.yml"
          puts "  external_types:"
          unique_types.each { |type| puts "    - #{type}" }
          puts ""
        end

        def format_collection_name(table_name) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength
          # Convert t_object -> objects, t_package -> packages, etc.
          name = table_name.sub(/^t_/, "")
          case name
          when "object" then "classes"
          when "package" then "packages"
          when "attribute" then "attributes"
          when "connector" then "associations"
          when "diagram" then "diagrams"
          when "operation" then "operations"
          when "operationparams" then "operation parameters"
          when "diagramobjects" then "diagram objects"
          when "diagramlinks" then "diagram links"
          when "objectconstraint" then "constraints"
          when "taggedvalue" then "tagged values"
          when "objectproperties" then "properties"
          when "attributetag" then "attribute tags"
          when "xref" then "cross-references"
          when "stereotypes" then "stereotypes"
          when "datatypes" then "data types"
          when "constrainttypes" then "constraint types"
          when "connectortypes" then "connector types"
          when "diagramtypes" then "diagram types"
          when "objecttypes" then "object types"
          when "statustypes" then "status types"
          when "complexitytypes" then "complexity types"
          else name
          end
        end
      end
    end
  end
end
