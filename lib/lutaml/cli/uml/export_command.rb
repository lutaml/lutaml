# frozen_string_literal: true

require_relative "../output_formatter"
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
          DESC

          thor_class.option :format, type: :string, required: true,
                                     desc: "Export format (json|markdown)"
          thor_class.option :output, aliases: "-o", required: true,
                                     desc: "Output path"
          thor_class.option :package, type: :string, desc: "Filter by package"
          thor_class.option :recursive, type: :boolean, default: true,
                                        desc: "Include nested packages"
        end

        def run(lur_path) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          repo = load_repository(lur_path)

          exporter_class = case options[:format].downcase
                           when "json"
                             Lutaml::UmlRepository::Exporters::JsonExporter
                           when "markdown"
                             Lutaml::UmlRepository::Exporters::MarkdownExporter
                           else
                             puts OutputFormatter.error(
                               "Unknown format: #{options[:format]}",
                             )
                             raise Thor::Error,
                                   "Unknown format: #{options[:format]}"
                           end

          exporter = exporter_class.new(repo)

          OutputFormatter.progress("Exporting to #{options[:format]}")
          exporter.export(options[:output],
                          options.to_h.transform_keys(&:to_sym))
          OutputFormatter.progress_done

          puts OutputFormatter.success("Exported to #{options[:output]}")
        rescue StandardError => e
          OutputFormatter.progress_done(success: false)
          puts OutputFormatter.error("Export failed: #{e.message}")
          raise Thor::Error, "Export failed: #{e.message}"
        end

        private

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
