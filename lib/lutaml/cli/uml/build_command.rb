# frozen_string_literal: true

module Lutaml
  module Cli
    module Uml
      # BuildCommand builds LUR packages from XMI or QEA files
      class BuildCommand
        METADATA_OPTIONAL_FIELDS = %i[
          publisher license description homepage keywords authors maintainers
        ].freeze

        COLLECTION_NAMES = {
          "object" => "classes",
          "package" => "packages",
          "attribute" => "attributes",
          "connector" => "associations",
          "diagram" => "diagrams",
          "operation" => "operations",
          "operationparams" => "operation parameters",
          "diagramobjects" => "diagram objects",
          "diagramlinks" => "diagram links",
          "objectconstraint" => "constraints",
          "taggedvalue" => "tagged values",
          "objectproperties" => "properties",
          "attributetag" => "attribute tags",
          "xref" => "cross-references",
          "stereotypes" => "stereotypes",
          "datatypes" => "data types",
          "constrainttypes" => "constraint types",
          "connectortypes" => "connector types",
          "diagramtypes" => "diagram types",
          "objecttypes" => "object types",
          "statustypes" => "status types",
          "complexitytypes" => "complexity types",
        }.freeze

        SUMMARY_METADATA = {
          "Publisher" => :publisher,
          "License" => :license,
        }.freeze

        SUMMARY_CONTENTS = {
          "Packages:" => :total_packages,
          "Classes:" => :total_classes,
          "Data Types:" => :total_data_types,
          "Enumerations:" => :total_enums,
          "Diagrams:" => :total_diagrams,
        }.freeze

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
            lutaml uml build model.xmi --name "Urban Model" --version "2.0" \
              --publisher "City Planning" --license "CC-BY-4.0"

            # Load metadata from file
            lutaml uml build model.xmi --metadata-file package-info.yaml
          DESC

          thor_class.option :output, aliases: "-o", type: :string,
                                     desc: "Output .lur file path " \
                                           "(default: input file with .lur " \
                                           "extension)"

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

        def run(model_path) # rubocop:disable Metrics/AbcSize
          validate_input_file(model_path)

          output_path = resolve_output_path(model_path)
          is_qea = model_path.end_with?(".qea")

          repo, qea_result = parse_source(model_path, is_qea)
          validate_qea_result(qea_result)
          validate_repository(repo) if should_validate?(is_qea)

          metadata = build_metadata
          export_package(repo, output_path, metadata)
          display_build_summary(metadata, repo, output_path)
        rescue StandardError => e
          OutputFormatter.progress_done(success: false)
          puts OutputFormatter.error("Failed to build package: #{e.message}")
          puts e.backtrace.first(5).join("\n") if ENV["DEBUG"]
          raise Thor::Error, "Failed to build package: #{e.message}"
        end

        private

        def validate_input_file(model_path)
          return if File.exist?(model_path)

          puts OutputFormatter.error("Model file not found: #{model_path}")
          raise Thor::Error, "Model file not found: #{model_path}"
        end

        def resolve_output_path(model_path)
          options[:output] || model_path.sub(/\.(xmi|qea)$/i, ".lur")
        end

        def should_validate?(is_qea)
          (options[:validate] || options[:strict]) && !is_qea
        end

        def parse_source(model_path, is_qea)
          if is_qea
            parse_qea_with_validation(model_path)
          else
            OutputFormatter.progress("Parsing XMI file")
            repo = Lutaml::UmlRepository::Repository.from_xmi(model_path)
            OutputFormatter.progress_done
            [repo, nil]
          end
        end

        def validate_qea_result(qea_result)
          return unless qea_result && options[:validate]

          display_qea_validation_result(qea_result)
          fail_build!("validation errors") if options[:strict] && qea_result.has_errors?
        end

        def validate_repository(repo)
          OutputFormatter.progress("Validating repository")
          result = repo.validate(verbose: options[:verbose])
          OutputFormatter.progress_done

          display_verbose_validation(result.validation_details) if options[:verbose] && result.validation_details
          return if result.valid?

          handle_validation_failure(result)
        end

        def handle_validation_failure(result)
          handle_validation_result(result)
          display_unresolved_types(result.external_references) if result.external_references&.any?
          fail_build!("validation errors") if options[:strict] && result.errors.any?
        end

        def fail_build!(reason)
          puts ""
          puts OutputFormatter.error("Build failed due to #{reason}")
          raise Thor::Error, "Build failed due to #{reason}"
        end

        def export_package(repo, output_path, metadata)
          export_options = {
            serialization_format: (
              options[:format] || options["format"] || "yaml"
            ).to_sym,
            metadata: metadata,
          }

          OutputFormatter.progress("Exporting to LUR package")
          repo.export_to_package(output_path, export_options)
          OutputFormatter.progress_done
        end

        def display_build_summary(metadata, repo, output_path) # rubocop:disable Metrics/AbcSize
          stats = repo.statistics
          puts ""
          puts OutputFormatter.success("Package built successfully: #{output_path}")
          puts ""
          puts "Package Metadata:"
          puts "  Name:          #{metadata.name}"
          puts "  Version:       #{metadata.version}"
          SUMMARY_METADATA.each do |label, attr|
            value = metadata.public_send(attr)
            puts "  #{label.ljust(15)}#{value}" if value
          end
          puts ""
          puts "Package Contents:"
          SUMMARY_CONTENTS.each do |label, key|
            puts "  #{label.ljust(15)} #{stats[key]}"
          end
        end

        def build_metadata # rubocop:disable Metrics/AbcSize
          return load_metadata_from_file(options[:metadata_file]) if options[:metadata_file]

          metadata_attrs = {
            name: options[:name] || File.basename(options[:output] || "model",
                                                  ".lur"),
            version: options[:version] || "1.0",
            serialization_format: (options[:format] || "yaml").to_s,
          }

          merge_optional_fields(metadata_attrs, options)

          Lutaml::UmlRepository::PackageMetadata.new(**metadata_attrs)
        end

        def merge_optional_fields(target, source)
          METADATA_OPTIONAL_FIELDS.each do |field|
            value = source[field]
            next unless value
            next if field == :authors && value.empty?

            target[field] = value
          end
        end

        def load_metadata_from_file(file_path) # rubocop:disable Metrics/AbcSize
          unless File.exist?(file_path)
            raise Thor::Error,
                  "Metadata file not found: #{file_path}"
          end

          require "yaml"
          metadata_hash = YAML.load_file(file_path)
          merge_optional_fields_into(metadata_hash, options)
          metadata_hash["serialization_format"] ||= (
            options[:format] || "yaml"
          ).to_s

          Lutaml::UmlRepository::PackageMetadata.from_hash(metadata_hash)
        rescue Psych::SyntaxError => e
          raise Thor::Error, "Invalid YAML in metadata file: #{e.message}"
        rescue ArgumentError => e
          raise Thor::Error, "Invalid metadata: #{e.message}"
        end

        def merge_optional_fields_into(hash, source)
          METADATA_OPTIONAL_FIELDS.each do |field|
            value = source[field]
            next unless value
            next if field == :authors && value.empty?

            hash[field.to_s] = value
          end
        end

        def handle_validation_result(result)
          limit = resolve_error_limit(result)

          if result.warnings.any?
            puts ""
            display_messages(result.warnings, "Validation warnings", :warning,
                             limit)
          end

          if result.errors.any?
            puts ""
            display_messages(result.errors, "Validation errors", :error, limit)
          end
        end

        def resolve_error_limit(result)
          if options[:limit_errors]
            options[:limit_errors]
          elsif result.warnings.size + result.errors.size < 100
            nil
          else
            50
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

          return unless limit && total > limit

          puts ""
          puts OutputFormatter.colorize(
            "  ... and #{total - limit} more #{type}s " \
            "(use --limit-errors to adjust)",
            :yellow,
          )
        end

        def parse_qea_with_validation(qea_path)
          if options[:validate]
            puts OutputFormatter.colorize(
              "⋯ Parsing QEA file with validation...", :cyan
            )

            result = Lutaml::Qea.parse(qea_path, validate: true)
            document = result[:document]
            validation_result = result[:validation_result]
            puts " #{OutputFormatter.colorize('✓', :green)}"
            puts ""

            repo = Lutaml::UmlRepository::Repository.new(document: document)
            [repo, validation_result]
          else
            repo = parse_qea_with_progress(qea_path)
            [repo, nil]
          end
        end

        def parse_qea_with_progress(qea_path) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          puts OutputFormatter.colorize("⋯ Parsing QEA file...", :cyan)

          loader = Lutaml::Qea::Services::DatabaseLoader.new(qea_path)

          current_table = nil
          loader.on_progress do |table_name, current, total|
            if current_table != table_name
              current_table = table_name
              collection_name = format_collection_name(table_name)
              print "\r  ⋯ Loading #{collection_name}..."
              $stdout.flush
            end
            if current == total
              puts " #{OutputFormatter.colorize('✓', :green)} (#{total})"
            end
          end

          database = loader.load

          print "  ⋯ Transforming to UML..."
          $stdout.flush

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

        def display_verbose_validation(validation_details)
          puts ""
          puts OutputFormatter.colorize("Detailed Type Validation:", :cyan)
          puts ""

          validation_details.each { |detail| display_class_validation(detail) }
        end

        def display_class_validation(detail)
          puts OutputFormatter.colorize("Class: #{detail[:class_name]}", :cyan)
          detail[:attributes].each { |attr| display_attribute_detail(attr) }
          puts ""
        end

        def display_attribute_detail(attr_detail)
          symbol = if attr_detail[:valid]
                     OutputFormatter.colorize("✓", :green)
                   else
                     OutputFormatter.colorize("✗", :red)
                   end
          puts "  #{symbol} #{attr_detail[:attribute_name]}: #{attr_detail[:type_value]}"
          if attr_detail[:resolved_to]
            puts "      → #{attr_detail[:resolved_to]}"
          elsif !attr_detail[:valid]
            puts "      → (not found)"
          end
        end

        def display_unresolved_types(external_references) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
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

        def format_collection_name(table_name)
          COLLECTION_NAMES.fetch(table_name.sub(/^t_/, ""), table_name)
        end
      end
    end
  end
end
