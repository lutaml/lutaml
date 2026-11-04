# frozen_string_literal: true

require "thor"
require_relative "base_command"

module Lutaml
  module Xsd
    module Commands
      # Metadata management commands
      # Handles get and set operations for package metadata
      class MetadataCommand < Thor
        class_option :verbose, type: :boolean, default: false

        desc "get PACKAGE [KEY]", "Get package metadata"
        long_desc <<~DESC
          Get metadata from an LXR package.

          If KEY is provided, returns just that metadata field.
          If --all is used, returns all metadata fields.

          Examples:
            lutaml-xsd package metadata get schemas.lxr version
            lutaml-xsd package metadata get schemas.lxr --all
            lutaml-xsd package metadata get schemas.lxr --format json
        DESC
        option :all, type: :boolean, desc: "Show all metadata"
        option :format, type: :string, default: "text", enum: %w[text json yaml]
        def get(package_path, key = nil)
          GetCommand.new(package_path, key, options).run
        end

        desc "set PACKAGE", "Set package metadata"
        long_desc <<~DESC
          Set metadata values in a package, creating a new package file.

          Examples:
            lutaml-xsd package metadata set schemas.lxr --set "version=2.0" -o updated.lxr
            lutaml-xsd package metadata set schemas.lxr --set "version=2.0" --set "description=New" -o updated.lxr
        DESC
        option :set, type: :array, desc: "Set metadata key=value pairs"
        option :output, type: :string, aliases: "-o", required: true,
                        desc: "Output package path"
        def set(package_path)
          SetCommand.new(package_path, options).run
        end

        # Get command implementation
        class GetCommand < BaseCommand
          def initialize(package_path, key, options)
            super(options)
            @package_path = package_path
            @key = key
          end

          def run
            pkg = SchemaRepositoryPackage.new(@package_path)
            raw_metadata = pkg.metadata

            # Load metadata if not already loaded
            unless raw_metadata
              validation = pkg.validate
              unless validation.valid?
                error "Failed to load package metadata"
                validation.errors.each { |err| error "  - #{err}" }
                raise CommandError
              end
              raw_metadata = validation.metadata
            end

            # Filter out internal lutaml-model fields
            metadata = raw_metadata.reject do |k, _|
              k.to_s.start_with?("_") || k == :using_default
            end

            # Show specific key or all
            if @key
              value = metadata[@key.to_sym] || metadata[@key]
              if value.nil?
                error "Metadata key '#{@key}' not found"
                raise CommandError
              end
              output value.to_s
            elsif options[:all]
              case options[:format]
              when "json"
                require "json"
                output JSON.pretty_generate(metadata)
              when "yaml"
                require "yaml"
                output metadata.to_yaml
              else
                # Text format - table
                display_metadata_table(metadata)
              end
            else
              error "Please specify a KEY or use --all"
              raise CommandError
            end
          rescue StandardError => e
            error "Failed to get metadata: #{e.message}"
            verbose_output e.backtrace.join("\n") if verbose?
            raise CommandError
          end

          private

          def display_metadata_table(metadata)
            require "table_tennis"

            rows = metadata.map do |key, value|
              {
                "Key" => key.to_s,
                "Value" => format_value(value),
              }
            end

            table = TableTennis.new(rows)
            output table
          end

          def format_value(value)
            case value
            when Array
              "(#{value.size} items)"
            when Hash
              "(#{value.size} entries)"
            else
              value.to_s
            end
          end
        end

        # Set command implementation
        class SetCommand < BaseCommand
          def initialize(package_path, options)
            super(options)
            @package_path = package_path
          end

          def run
            # Load existing package
            old_pkg = SchemaRepositoryPackage.new(@package_path)
            repo = old_pkg.load_repository

            # Get existing metadata
            validation = old_pkg.validate
            unless validation.valid?
              error "Cannot modify invalid package"
              validation.errors.each { |err| error "  - #{err}" }
              raise CommandError
            end

            # Get current metadata as a hash, excluding internal fields
            current_metadata = validation.metadata.to_h.reject do |k, _|
              k.to_s.start_with?("_") || k == :using_default
            end

            # Parse and apply --set options
            (options[:set] || []).each do |setting|
              key, value = setting.split("=", 2)
              unless value
                error "Invalid setting format: #{setting}"
                error "Expected format: key=value"
                raise CommandError
              end
              current_metadata[key] = value # Use string key, not symbol
            end

            # Preserve package configuration from original package
            xsd_mode = (validation.metadata["xsd_mode"] || :include_all).to_sym
            resolution_mode = (validation.metadata["resolution_mode"] || :resolved).to_sym
            serialization_format = (validation.metadata["serialization_format"] || :marshal).to_sym

            # Create new package with updated metadata
            repo.to_package(
              options[:output],
              xsd_mode: xsd_mode,
              resolution_mode: resolution_mode,
              serialization_format: serialization_format,
              metadata: current_metadata,
            )

            output "✓ Package created with updated metadata: #{options[:output]}"
          rescue StandardError => e
            error "Failed to set metadata: #{e.message}"
            verbose_output e.backtrace.join("\n") if verbose?
            raise CommandError
          end
        end
      end
    end
  end
end
