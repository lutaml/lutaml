# frozen_string_literal: true

require_relative "../output_formatter"
module Lutaml
  module Cli
    module Uml
      # InfoCommand displays package metadata
      class InfoCommand
        attr_reader :options

        def initialize(options = {})
          @options = options
        end

        def self.add_options_to(thor_class, _method_name)
          thor_class.long_desc <<-DESC
          Display metadata and statistics for a LUR package without loading
          the full repository.

          Example:
            lutaml uml info model.lur

            lutaml uml info model.lur --format json
          DESC

          thor_class.option :format, type: :string, default: "text",
                                     desc: "Output format (text|yaml|json)"
        end

        def run(lur_path)
          unless File.exist?(lur_path)
            puts OutputFormatter.error("Package file not found: #{lur_path}")
            exit 1
          end

          require "zip"
          require "yaml"

          begin
            Zip::File.open(lur_path) do |zip|
              metadata_entry = zip.find_entry("metadata.yaml")
              unless metadata_entry
                puts OutputFormatter.error("Invalid package: missing metadata")
                exit 1
              end

              metadata = YAML.safe_load(metadata_entry.get_input_stream.read)

              if options[:format] == "text"
                display_package_info(metadata)
              else
                puts OutputFormatter.format(metadata, format: options[:format])
              end
            end
          rescue StandardError => e
            puts OutputFormatter.error("Failed to read package info: #{e.message}")
            exit 1
          end
        end

        private

        def display_package_info(metadata)
          puts OutputFormatter.colorize("Package Information", :cyan)
          puts "=" * 50
          puts ""
          puts "Name:             #{metadata['name']}"
          puts "Version:          #{metadata['version']}"
          puts "Created:          #{metadata['created_at']}"
          puts "Created by:       #{metadata['created_by']}"
          puts "LutaML Version:   #{metadata['lutaml_version']}"
          puts "Format:           #{metadata['serialization_format']}"
          puts ""

          if metadata["statistics"]
            stats = metadata["statistics"]
            puts OutputFormatter.colorize("Contents:", :yellow)
            puts "  Packages:       #{stats['total_packages']}"
            puts "  Classes:        #{stats['total_classes']}"
            puts "  Data Types:     #{stats['total_data_types']}"
            puts "  Enumerations:   #{stats['total_enums']}"
            puts "  Diagrams:       #{stats['total_diagrams']}"
          end
        end
      end
    end
  end
end
