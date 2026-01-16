# frozen_string_literal: true

require_relative "../output_formatter"
module Lutaml
  module Cli
    module Uml
      # InfoCommand displays package metadata
      class InfoCommand
        attr_reader :options

        def initialize(options = {})
          @options = options.transform_keys(&:to_sym)
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

        def run(lur_path) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          unless File.exist?(lur_path)
            puts OutputFormatter.error("Package file not found: #{lur_path}")
            raise Thor::Error, "Package file not found: #{lur_path}"
          end

          require "zip"
          require "yaml"

          begin
            Zip::File.open(lur_path) do |zip|
              metadata_entry = zip.find_entry("metadata.yaml")
              unless metadata_entry
                puts OutputFormatter.error("Invalid package: missing metadata")
                raise Thor::Error, "Invalid package: missing metadata"
              end

              # Permit all Lutaml::Uml classes for safe loading
              uml_constants = Lutaml::Uml.constants
              uml_classes = uml_constants.map do |const_name|
                constant_value = Lutaml::Uml.const_get(const_name)
                constant_value if constant_value.is_a?(Class)
              end.compact
              permitted_classes = [Symbol, Time, Date, DateTime, uml_classes]
                .flatten

              metadata = YAML.safe_load(
                metadata_entry.get_input_stream.read,
                permitted_classes: permitted_classes,
                aliases: true,
              )

              if options[:format] == "text"
                display_package_info(metadata)
              else
                puts OutputFormatter.format(metadata, format: options[:format])
              end
            end
          rescue Thor::Error
            raise
          rescue StandardError => e
            puts OutputFormatter.error("Failed to read package info: " \
                                       "#{e.message}")
            raise Thor::Error, "Failed to read package info: #{e.message}"
          end
        end

        private

        def display_package_info(metadata) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
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
