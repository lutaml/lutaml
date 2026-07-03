# frozen_string_literal: true

module Lutaml
  module Cli
    module Uml
      # ExportCommand exports to structured formats
      class ExportCommand
        attr_reader :options

        def initialize(options = {})
          @options = options.transform_keys(&:to_sym)
        end

        def self.add_options_to(thor_class, _method_name)
          thor_class.long_desc <<-DESC
          Export repository data to various formats.

          Examples:
            lutaml uml export model.lur --format json -o model.json
            lutaml uml export model.lur --format markdown -o docs/
            lutaml uml export model.lur --format xsd --class Building -o b.xsd
            lutaml uml export model.lur --format json-schema --class Building -o b.json
          DESC

          thor_class.option :format, type: :string, required: true,
                                     desc: "Export format " \
                                           "(json|markdown|xsd|json-schema)"
          thor_class.option :output, aliases: "-o", required: true,
                                     desc: "Output path"
          thor_class.option :class, type: :string,
                                    desc: "Class to realize " \
                                          "(required for xsd|json-schema)"
          thor_class.option :package, type: :string, desc: "Filter by package"
          thor_class.option :recursive, type: :boolean, default: true,
                                        desc: "Include nested packages"
        end

        def run(lur_path)
          repo = load_repository(lur_path)

          case options[:format].downcase
          when "json", "markdown" then run_exporter(repo)
          when "xsd", "json-schema" then run_schema(repo)
          else raise Thor::Error, "Unknown format: #{options[:format]}"
          end
        rescue Thor::Error
          raise
        rescue StandardError => e
          fail_export(e)
        end

        private

        def run_exporter(repo)
          with_progress do
            exporter_class.new(repo).export(
              options[:output], options.to_h.transform_keys(&:to_sym)
            )
          end
        end

        # Schema realization (XSD / JSON Schema) via the lutaml-model bridge.
        def run_schema(repo)
          bridge = Lutaml::Schema::Bridge.new(repo.document)
          class_name = realization_class!(bridge)
          with_progress do
            File.write(options[:output], schema_content(bridge, class_name))
          end
        end

        def exporter_class
          if options[:format].casecmp?("json")
            Lutaml::UmlRepository::Exporters::JsonExporter
          else
            Lutaml::UmlRepository::Exporters::MarkdownExporter
          end
        end

        def schema_content(bridge, class_name)
          if options[:format].casecmp?("xsd")
            bridge.to_xsd(class_name)
          else
            bridge.to_json_schema(class_name)
          end
        end

        def realization_class!(bridge)
          class_name = options[:class]
          return class_name if class_name && !class_name.empty?

          raise Thor::Error,
                "--class is required for #{options[:format]} " \
                "(available: #{bridge.class_names.sort.join(', ')})"
        end

        def with_progress
          OutputFormatter.progress("Exporting to #{options[:format]}")
          yield
          OutputFormatter.progress_done
          puts OutputFormatter.success("Exported to #{options[:output]}")
        end

        def fail_export(error)
          OutputFormatter.progress_done(success: false)
          puts OutputFormatter.error("Export failed: #{error.message}")
          raise Thor::Error, "Export failed: #{error.message}"
        end

        def load_repository(lur_path, lazy: false)
          OutputFormatter.progress("Loading repository from #{lur_path}")
          repo = Lutaml::UmlRepository::Repository.from_package(lur_path)
          OutputFormatter.progress_done
          repo
        rescue StandardError => e
          OutputFormatter.progress_done(success: false)
          puts OutputFormatter.error("Failed to load repository: #{e.message}")
          raise Thor::Error, "Failed to load repository: #{e.message}"
        end
      end
    end
  end
end
