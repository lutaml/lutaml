# frozen_string_literal: true

require "yaml"
require "zip"
require "fileutils"
require "tmpdir"

module Lutaml
  module Xsd
    # Represents a schema repository package (ZIP file)
    # Handles package creation, validation, and loading
    # Provides a clean separation between package management and repository logic
    class SchemaRepositoryPackage
      # Package validation result
      class ValidationResult
        attr_reader :valid, :errors, :warnings, :metadata

        def initialize(valid:, errors: [], warnings: [], metadata: nil)
          @valid = valid
          @errors = errors
          @warnings = warnings
          @metadata = metadata
        end

        def valid?
          @valid
        end

        def to_h
          {
            valid?: valid?,
            errors: errors,
            warnings: warnings,
            metadata: metadata,
          }
        end
      end

      attr_reader :zip_path, :metadata, :repository

      # Create a new package instance
      # @param zip_path [String] Path to the ZIP package file
      def initialize(zip_path)
        @zip_path = zip_path
        @metadata = nil
        @repository = nil
      end

      # Load a package and its repository
      # @param zip_path [String] Path to the ZIP package file
      # @return [SchemaRepositoryPackage] Package instance with loaded repository
      def self.load(zip_path)
        package = new(zip_path)
        package.load_repository
        package
      end

      # Create a package from a schema repository
      # @param repository [SchemaRepository] Repository to package
      # @param output_path [String] Path for output ZIP file
      # @param config [PackageConfiguration] Package configuration
      # @param metadata [Hash] Additional metadata
      # @return [SchemaRepositoryPackage]
      def self.create(repository:, output_path:, config:, metadata: {})
        package = new(output_path)
        package.write_from_repository(repository, config, metadata)
        package
      end

      # Validate the package
      # @return [ValidationResult]
      def validate
        errors = []
        warnings = []

        # Check file exists
        unless File.exist?(zip_path)
          return ValidationResult.new(
            valid: false,
            errors: ["Package file not found: #{zip_path}"],
          )
        end

        metadata = nil
        schema_entries = []
        has_metadata = false

        begin
          # Read and validate ZIP structure
          Zip::File.open(zip_path) do |zipfile|
            zipfile.each do |entry|
              case entry.name
              when "metadata.yaml"
                has_metadata = true
                metadata = YAML.safe_load(
                  entry.get_input_stream.read,
                  permitted_classes: [Time, Date, Symbol],
                )
              when %r{^schemas/.+\.xsd$}, %r{^schemas/.+\.rng$}, %r{^schemas/.+\.rnc$}
                schema_entries << entry.name
              end
            end
          end

          # Validate structure
          validate_structure(has_metadata, schema_entries, errors)

          unless metadata
            return ValidationResult.new(valid: false,
                                        errors: errors)
          end

          # Validate metadata
          validate_metadata(metadata, schema_entries, errors, warnings)

          # Check self-containment
          validate_self_containment(metadata, errors, warnings)
        rescue Zip::Error => e
          errors << "Failed to read ZIP package: #{e.message}"
        rescue Psych::SyntaxError => e
          errors << "Invalid YAML in metadata: #{e.message}"
        rescue StandardError => e
          errors << "Package validation error: #{e.message}"
        end

        ValidationResult.new(
          valid: errors.empty?,
          errors: errors,
          warnings: warnings,
          metadata: metadata,
        )
      end

      # Load repository from this package
      # @return [SchemaRepository]
      def load_repository
        validation = validate
        unless validation.valid?
          raise Error,
                "Invalid package: #{validation.errors.join(', ')}"
        end

        @metadata = validation.metadata
        @repository = extract_and_build_repository
      end

      # Get schemas from the repository
      # @return [Array<Schema>] Array of schemas
      def schemas
        repository&.schemas || []
      end

      # Write package from repository
      # @param repository [SchemaRepository] Repository to write
      # @param config [PackageConfiguration] Package configuration
      # @param additional_metadata [Hash] Additional metadata
      # @return [String] Path to created package
      def write_from_repository(repository, config, additional_metadata = {})
        # Use PackageBuilder to build package data
        builder = PackageBuilder.new(config)
        package_data = builder.build(repository, additional_metadata)

        @metadata = package_data[:metadata]
        @repository = repository
        xsd_files = package_data[:xsd_files]
        serialized_schemas = package_data[:serialized_schemas]

        # Remove existing file if it exists to avoid duplicates
        FileUtils.rm_f(zip_path)

        # On Windows, give OS time to fully release file handles after deletion
        # This prevents "Permission denied" errors during ZIP file creation
        sleep 0.05 if Gem.win_platform?

        # Create ZIP file
        Zip::File.open(zip_path, create: true) do |zipfile|
          # Write metadata using Lutaml::Model's to_yaml
          zipfile.get_output_stream("metadata.yaml") do |f|
            f.write(@metadata.to_yaml)
          end

          # Write XSD files collected by bundler
          xsd_files.each do |source_path, package_data|
            if package_data.is_a?(Hash)
              # New format with rewritten content (include_all mode)
              zipfile.get_output_stream(package_data[:package_path]) do |f|
                f.write(package_data[:content])
              end
            else
              # Old format with just package_path string (allow_external mode)
              zipfile.add(package_data, source_path)
            end
          end

          # Write serialized schemas to schemas_data/ directory
          if serialized_schemas&.any?
            write_serialized_schemas(
              zipfile,
              serialized_schemas,
              xsd_files,
              config.serialization_format,
              repository.namespace_mappings,
            )
          end
        end

        zip_path
      end

      private

      # Validate package structure
      # @param has_metadata [Boolean] Whether metadata.yaml exists
      # @param schema_entries [Array<String>] Schema file entries
      # @param errors [Array<String>] Error collection
      def validate_structure(has_metadata, schema_entries, errors)
        errors << "Invalid package structure: missing metadata.yaml" unless has_metadata

        return unless schema_entries.empty?

        errors << "Invalid package structure: no schemas found in schemas/ directory"
      end

      # Validate metadata content
      # @param metadata [Hash] Metadata hash
      # @param schema_entries [Array<String>] Schema file entries
      # @param errors [Array<String>] Error collection
      # @param warnings [Array<String>] Warning collection
      def validate_metadata(metadata, schema_entries, errors, warnings)
        validate_metadata_structure(metadata, errors)
        validate_metadata_fields(metadata, errors, warnings)
        validate_schema_references(metadata, schema_entries, errors)
      end

      # Validate metadata has required structure
      # @param metadata [Hash] Metadata hash
      # @param errors [Array<String>] Error collection
      def validate_metadata_structure(metadata, errors)
        required_fields = %w[files namespace_mappings created_at
                             lutaml_xsd_version]
        required_fields.each do |field|
          errors << "Metadata missing required field: #{field}" unless metadata.key?(field)
        end

        # Validate field types
        validate_field_type(metadata, "files", Array, errors)
        validate_field_type(metadata, "namespace_mappings", Array, errors)
        return unless metadata.key?("schema_location_mappings")

        validate_field_type(metadata, "schema_location_mappings", Array,
                            errors)
      end

      # Validate a field has correct type
      # @param metadata [Hash] Metadata hash
      # @param field [String] Field name
      # @param expected_type [Class] Expected class
      # @param errors [Array<String>] Error collection
      def validate_field_type(metadata, field, expected_type, errors)
        return unless metadata[field] && !metadata[field].is_a?(expected_type)

        errors << "Metadata field '#{field}' must be a #{expected_type.name.downcase}"
      end

      # Validate metadata field values
      # @param metadata [Hash] Metadata hash
      # @param errors [Array<String>] Error collection
      # @param warnings [Array<String>] Warning collection
      def validate_metadata_fields(metadata, errors, warnings)
        # Validate namespace mappings
        validate_namespace_mappings(metadata["namespace_mappings"], errors)

        # Check version compatibility
        validate_version_compatibility(metadata["lutaml_xsd_version"], warnings)
      end

      # Validate namespace mappings structure
      # @param mappings [Array] Namespace mappings
      # @param errors [Array<String>] Error collection
      def validate_namespace_mappings(mappings, errors)
        return unless mappings.is_a?(Array)

        mappings.each_with_index do |mapping, idx|
          unless mapping.is_a?(Hash)
            errors << "Namespace mapping at index #{idx} must be a hash"
            next
          end
          errors << "Namespace mapping at index #{idx} missing required fields: prefix, uri" unless mapping["prefix"] && mapping["uri"]
        end
      end

      # Validate version compatibility
      # @param package_version [String] Version in package
      # @param warnings [Array<String>] Warning collection
      def validate_version_compatibility(package_version, warnings)
        return unless package_version

        pkg_ver = Gem::Version.new(package_version)
        cur_ver = Gem::Version.new(Lutaml::Xsd::VERSION)

        warnings << "Package created with newer lutaml-xsd (#{package_version}) than current (#{Lutaml::Xsd::VERSION})" if pkg_ver > cur_ver
      rescue ArgumentError
        # Version parsing error handled elsewhere
      end

      # Validate schema file references
      # @param metadata [Hash] Metadata hash
      # @param schema_entries [Array<String>] Actual schema entries in ZIP
      # @param errors [Array<String>] Error collection
      def validate_schema_references(metadata, schema_entries, errors)
        return unless metadata["files"].is_a?(Array)

        # Extract basenames from schema entries
        schema_basenames = schema_entries.map { |e| File.basename(e) }

        # Check each file in metadata has corresponding entry
        metadata["files"].each do |file_ref|
          basename = File.basename(file_ref)
          errors << "Metadata references schema '#{file_ref}' not found in package" unless schema_basenames.include?(basename)
        end
      end

      # Validate package is self-contained (no external dependencies)
      # @param metadata [Hash] Metadata hash
      # @param errors [Array<String>] Error collection
      # @param warnings [Array<String>] Warning collection
      def validate_self_containment(metadata, errors, warnings)
        # Extract all schema locations from schema_location_mappings
        return unless metadata["schema_location_mappings"].is_a?(Array)

        metadata["schema_location_mappings"].each do |mapping|
          to_location = mapping["to"]
          next unless to_location

          # Check if location points outside package
          if to_location.start_with?("http://", "https://")
            errors << "Package has external dependency: #{to_location}"
          elsif to_location.start_with?("/", "../")
            warnings << "Package may have external file dependency: #{to_location}"
          end
        end
      end

      # Extract package and build repository
      #
      # Extracts ZIP package contents to a temporary directory and builds
      # a SchemaRepository from the extracted files. The temporary directory
      # is automatically cleaned up when the repository is garbage collected.
      #
      # @return [SchemaRepository] Repository loaded from package
      # @raise [Error] If package validation fails
      def extract_and_build_repository
        metadata = nil
        schema_files = []
        serialized_data_files = {}

        temp_dir = Dir.mktmpdir("lutaml_xsd_package")

        # Extract package contents to temporary directory
        Zip::File.open(zip_path) do |zipfile|
          zipfile.each do |entry|
            # Skip directory entries (they're created automatically by mkdir_p)
            next if entry.directory?

            extract_path = File.join(temp_dir, entry.name)
            FileUtils.mkdir_p(File.dirname(extract_path))

            # Extract file content directly using explicit file I/O
            # This is more reliable than entry.extract() which can have
            # path interpretation issues with absolute paths on some platforms
            File.binwrite(extract_path, entry.get_input_stream.read)

            # Categorize extracted files
            if entry.name == "metadata.yaml"
              metadata = YAML.load_file(extract_path)
            elsif entry.name.start_with?("schemas/")
              schema_files << extract_path
            elsif entry.name.start_with?("schemas_data/")
              # Track serialized schema files for later deserialization
              serialized_data_files[entry.name] = extract_path
            end
          end
        end

        # Build repository from extracted files
        repository = build_repository_from_metadata(metadata, schema_files)

        # Load serialized schemas if present
        if serialized_data_files.any?
          load_serialized_schemas_from_files(repository, serialized_data_files,
                                             metadata)
        end

        # Store temp directory path so it can be cleaned up later
        # The repository needs these files to exist during parse/resolve
        repository.instance_variable_set(:@temp_extraction_dir, temp_dir)

        # Set up cleanup when repository is garbage collected
        ObjectSpace.define_finalizer(repository, proc do
          FileUtils.remove_entry(temp_dir) if temp_dir && File.exist?(temp_dir)
        end)

        repository
      end

      # Build repository from metadata and files
      # @param metadata [Hash] Package metadata
      # @param schema_files [Array<String>] Extracted schema file paths
      # @return [SchemaRepository]
      def build_repository_from_metadata(metadata, schema_files)
        repository = SchemaRepository.new(
          files: schema_files,
          schema_location_mappings: parse_schema_location_mappings(metadata["schema_location_mappings"]),
          namespace_mappings: parse_namespace_mappings(metadata["namespace_mappings"]),
        )

        # Get serialization format from metadata (default to parse for backward compatibility)
        serialization_format = (metadata["serialization_format"] || "parse").to_sym

        # Load schemas based on serialization format
        case serialization_format
        when :parse
          # Parse XSD files (slowest but most compatible)
          repository.parse if metadata["xsd_mode"] == "include_all" && metadata["resolution_mode"] == "resolved"
        when :marshal, :json, :yaml
          # Load from serialized schemas_data/ (fast)
          # This will be handled during ZIP extraction
        end

        # Backward compatibility: load from old serialized_schemas format
        if metadata["serialized_schemas"]&.any?
          config = PackageConfiguration.new(
            xsd_mode: metadata["xsd_mode"] || :include_all,
            resolution_mode: metadata["resolution_mode"] || :resolved,
            serialization_format: serialization_format,
          )
          builder = PackageBuilder.new(config)
          builder.load(repository, metadata)
        end

        repository
      end

      # Parse schema location mappings from metadata
      # @param mappings [Array<Hash>] Schema location mapping hashes
      # @return [Array<SchemaLocationMapping>]
      def parse_schema_location_mappings(mappings)
        return [] unless mappings.is_a?(Array)

        mappings.map do |m|
          SchemaLocationMapping.new(**m.transform_keys(&:to_sym))
        end
      end

      # Parse namespace mappings from metadata
      # @param mappings [Array<Hash>] Namespace mapping hashes
      # @return [Array<NamespaceMapping>]
      def parse_namespace_mappings(mappings)
        return [] unless mappings.is_a?(Array)

        mappings.map do |m|
          NamespaceMapping.new(**m.transform_keys(&:to_sym))
        end
      end

      # Write schemas to ZIP file
      # @param zipfile [Zip::File] ZIP file instance
      # @param repository [SchemaRepository] Repository with schemas
      def write_schemas_to_zip(zipfile, repository)
        # Create a map to track which files we've added (to avoid duplicates)
        # Use both basename and absolute path for detection
        added_files = {}
        added_paths = Set.new

        # First, add the main entry point files from repository.files
        (repository.files || []).each do |file_path|
          next unless File.exist?(file_path)

          abs_path = File.absolute_path(file_path)
          basename = File.basename(file_path)

          # Skip if already added by absolute path
          next if added_paths.include?(abs_path)

          zip_path = "schemas/#{basename}"
          zipfile.add(zip_path, file_path)
          added_files[basename] = file_path
          added_paths.add(abs_path)
        end

        # Then, add all imported/included schema dependencies
        all_schemas = repository.all_schemas

        # Convert schema location mappings to Glob format for resolution
        glob_mappings = (repository.schema_location_mappings || []).map(&:to_glob_format)

        all_schemas.each_key do |schema_location|
          # Resolve the schema location to actual file path using mappings
          resolved_path = resolve_schema_location(schema_location,
                                                  glob_mappings)

          next unless resolved_path && File.exist?(resolved_path)

          abs_path = File.absolute_path(resolved_path)
          basename = File.basename(resolved_path)

          # Skip if we've already added this file (by absolute path or basename)
          next if added_paths.include?(abs_path) || added_files.key?(basename)

          # Add to ZIP using basename in schemas/ directory
          zip_path = "schemas/#{basename}"
          zipfile.add(zip_path, resolved_path)
          added_files[basename] = resolved_path
          added_paths.add(abs_path)
        end
      end

      # Serialize all parsed schemas from the repository
      # @param repository [SchemaRepository] Repository with parsed schemas
      # @return [Array<SerializedSchema>] Array of serialized schemas
      def serialize_schemas(repository)
        all_schemas = repository.all_schemas

        all_schemas.map do |file_path, schema|
          SerializedSchema.from_schema(file_path, schema)
        end
      end

      # Load serialized schemas into repository
      # @param repository [SchemaRepository] Repository to load into
      # @param serialized_schemas_data [Array<Hash>] Serialized schema data from metadata
      def load_serialized_schemas(_repository, serialized_schemas_data)
        return unless serialized_schemas_data.is_a?(Array)

        # Parse SerializedSchema objects from metadata hashes
        serialized_schemas = serialized_schemas_data.map do |data|
          if data.is_a?(SerializedSchema)
            data
          else
            SerializedSchema.new(**data.transform_keys(&:to_sym))
          end
        end

        # Deserialize each schema and add to global processed_schemas cache
        serialized_schemas.each do |serialized_schema|
          schema = serialized_schema.to_schema
          Lutaml::Xml::Schema::Xsd::Schema.schema_processed(
            serialized_schema.file_path, schema
          )
        end

        # Don't mark as resolved yet - let the caller call resolve()
        # which will build the type index from the deserialized schemas
      end

      # Write serialized schemas to ZIP file
      # @param zipfile [Zip::File] ZIP file instance
      # @param serialized_schemas [Hash] Map of file_path => serialized data
      # @param xsd_files [Hash] Map of source_path => package info (with renamed paths)
      # @param format [Symbol] Serialization format
      # @param namespace_mappings [Array<NamespaceMapping>] Namespace mappings
      def write_serialized_schemas(zipfile, serialized_schemas, xsd_files,
format, namespace_mappings)
        extension = case format
                    when :marshal then "marshal"
                    when :json then "json"
                    when :yaml then "yaml"
                    else return
                    end

        # Build a mapping from each xsd source file to its renamed basename in the package
        # xsd_files: absolute_source_path => {package_path: "schemas/renamed.xsd", ...}
        source_to_basename = {}
        xsd_files.each do |source_abs_path, package_info|
          renamed_path = package_info.is_a?(Hash) ? package_info[:package_path] : package_info
          if renamed_path
            source_to_basename[source_abs_path] =
              File.basename(renamed_path, ".*")
          end
        end

        # Get all schemas from global cache
        all_schemas = Lutaml::Xml::Schema::Xsd::Schema.processed_schemas

        serialized_schemas.each do |schema_location, data|
          # Get schema object
          schema = all_schemas[schema_location]

          # Find the matching source file for this schema location
          # We need to check which xsd_files entry this schema_location corresponds to
          matching_basename = nil

          xsd_files.each_key do |source_abs_path|
            # Check if this source file matches the schema location
            # Schema locations in cache can be relative or absolute
            if schema_location.start_with?("/")
              # Absolute path in cache
              if File.absolute_path(schema_location) == File.absolute_path(source_abs_path)
                matching_basename = source_to_basename[source_abs_path]
                break
              end
            else
              # Relative path in cache - check if it refers to the same file
              # by comparing the actual file's basename and checking if source path ends with it
              schema_basename = File.basename(schema_location)
              if source_abs_path.end_with?(schema_basename,
                                           "/#{schema_location}")
                matching_basename = source_to_basename[source_abs_path]
                break
              end
            end
          end

          # Use the renamed basename from bundler, or fall back to schema location basename
          basename = matching_basename || File.basename(schema_location, ".*")

          # Use basename directly (bundler has already made it unique)
          unique_name = resolve_schema_name(basename, schema,
                                            namespace_mappings)

          zip_path = "schemas_data/#{unique_name}.#{extension}"

          zipfile.get_output_stream(zip_path) do |f|
            f.write(data)
          end
        end
      end

      # Load serialized schemas from extracted files
      #
      # Deserializes pre-parsed schemas from the schemas_data/ directory in
      # the package and registers them in the global schema cache. This is
      # significantly faster than parsing XSD files from scratch.
      #
      # @param repository [SchemaRepository] Repository to load schemas into
      # @param serialized_files [Hash] Map of zip_path => extracted file path
      # @param metadata [Hash] Package metadata containing serialization format
      # @return [void]
      def load_serialized_schemas_from_files(repository, serialized_files,
metadata)
        serialization_format = (metadata["serialization_format"] || "parse").to_sym
        return if serialization_format == :parse

        builder = PackageBuilder.new(
          PackageConfiguration.new(
            xsd_mode: metadata["xsd_mode"] || :include_all,
            resolution_mode: metadata["resolution_mode"] || :resolved,
            serialization_format: serialization_format,
          ),
        )

        namespace_mappings = repository.namespace_mappings || []

        serialized_files.each_value do |file_path|
          # Use binary mode for reading to avoid line ending conversion on Windows
          # which would corrupt Marshal data
          data = File.binread(file_path)
          schema = builder.deserialize_schema(data, serialization_format)

          # Extract unique name from serialized file (includes prefix or hash)
          # The name may include a namespace prefix for disambiguation
          serialized_basename = File.basename(file_path, ".*")

          # Find matching XSD file by generating unique name from schema's namespace
          # This matches the naming strategy used during package creation
          actual_schema_path = repository.files.find do |schema_file|
            xsd_basename = File.basename(schema_file, ".*")
            # Generate unique name using namespace prefix approach
            unique_name = resolve_schema_name(xsd_basename, schema,
                                              namespace_mappings)
            unique_name == serialized_basename
          end

          unless actual_schema_path
            # Fallback: try to match just by basename (without prefix/hash suffix)
            # This handles both old hash format (_[a-f0-9]+) and new prefix format (_prefix)
            # Provides backward compatibility with older package formats
            xsd_basename_only = serialized_basename.sub(/_[a-z0-9]+$/i, "")
            actual_schema_path = repository.files.find do |f|
              File.basename(f, ".*") == xsd_basename_only
            end || "#{xsd_basename_only}.xsd"
          end

          # Register schema in global cache using the actual schema file path
          # This makes the schema available for type resolution and queries
          Lutaml::Xml::Schema::Xsd::Schema.schema_processed(actual_schema_path,
                                                            schema)
        end
      end

      # Resolve schema name using namespace prefix
      # @param basename [String] The basename to use (may be renamed)
      # @param schema [Schema] Schema object for namespace-based naming
      # @param namespace_mappings [Array<NamespaceMapping>] Namespace mappings
      # @return [String] Unique schema name using namespace prefix
      def resolve_schema_name(basename, schema, namespace_mappings = [])
        resolver = SchemaNameResolver.new(namespace_mappings)
        resolver.resolve_name(basename, schema)
      end

      # Resolve a schema location to actual file path using mappings
      # @param location [String] Schema location (may be relative)
      # @param mappings [Array<Hash>] Schema mappings in Glob format
      # @return [String, nil] Resolved file path or nil
      def resolve_schema_location(location, mappings)
        # Try each mapping
        mappings.each do |mapping|
          from = mapping[:from]
          to = mapping[:to]

          if from.is_a?(Regexp)
            # Pattern matching
            if location&.match?(from)
              # Use gsub to apply the pattern replacement
              return location.gsub(from, to)
            end
          elsif location == from
            # Exact match
            return to
          end
        end

        # If no mapping found, return nil (location couldn't be resolved)
        nil
      end
    end
  end
end
