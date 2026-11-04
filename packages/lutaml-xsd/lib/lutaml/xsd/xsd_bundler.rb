# frozen_string_literal: true

module Lutaml
  module Xsd
    # Handles collection and bundling of XSD files for packages
    # Manages schema location rewriting for portability
    class XsdBundler
      # Collect XSD files to include in package
      # @param repository [SchemaRepository] Repository with schemas
      # @param config [PackageConfiguration] Package configuration
      # @return [Hash] Map of source paths to package data
      #   Each value is a hash with:
      #   - package_path: Destination path in package
      #   - content: Rewritten XSD content (for include_all mode)
      def collect_xsd_files(repository, config)
        xsd_files = {}

        if config.include_all_xsds?
          collect_all_xsds(repository, xsd_files)
          rewrite_schema_locations(xsd_files, repository) if xsd_files.any?
        else
          collect_entry_point_xsds(repository, xsd_files)
        end

        xsd_files
      end

      private

      # Collect all XSD files including dependencies
      # @param repository [SchemaRepository] Repository with schemas
      # @param xsd_files [Hash] Map to populate with file paths
      def collect_all_xsds(repository, xsd_files)
        added_paths = Set.new

        # Add main entry point files
        (repository.files || []).each do |file_path|
          add_xsd_file(file_path, xsd_files, added_paths)
        end

        # Add all processed schemas (includes imports/includes)
        all_schemas = repository.all_schemas
        glob_mappings = (repository.schema_location_mappings || []).map(&:to_glob_format)

        all_schemas.each_key do |schema_location|
          resolved_path = resolve_schema_location(schema_location,
                                                  glob_mappings)
          add_xsd_file(resolved_path, xsd_files, added_paths) if resolved_path
        end

        # Add files referenced in schema_location_mappings
        # (Only add if it's a file, not a directory)
        (repository.schema_location_mappings || []).each do |mapping|
          to_path = mapping.to
          next unless to_path && File.exist?(to_path) && File.file?(to_path)

          add_xsd_file(to_path, xsd_files, added_paths)
        end
      end

      # Collect only entry point XSD files
      # @param repository [SchemaRepository] Repository with schemas
      # @param xsd_files [Hash] Map to populate with file paths
      def collect_entry_point_xsds(repository, xsd_files)
        added_paths = Set.new

        (repository.files || []).each do |file_path|
          add_xsd_file(file_path, xsd_files, added_paths)
        end
      end

      # Add an XSD file to the collection
      # @param file_path [String] Source file path
      # @param xsd_files [Hash] Map to populate
      # @param added_paths [Set] Set of already-added absolute paths
      def add_xsd_file(file_path, xsd_files, added_paths)
        return unless file_path && File.exist?(file_path)

        abs_path = File.absolute_path(file_path)
        return if added_paths.include?(abs_path)

        basename = File.basename(file_path)
        package_path = "schemas/#{basename}"

        # Handle name conflicts by appending directory name
        while xsd_files.value?(package_path)
          dir_name = File.basename(File.dirname(abs_path))
          basename = "#{dir_name}_#{basename}"
          package_path = "schemas/#{basename}"
        end

        xsd_files[abs_path] = package_path
        added_paths.add(abs_path)
      end

      # Resolve a schema location to actual file path
      # @param location [String] Schema location
      # @param mappings [Array<Hash>] Schema mappings in Glob format
      # @return [String, nil] Resolved file path or nil
      def resolve_schema_location(location, mappings)
        mappings.each do |mapping|
          from = mapping[:from]
          to = mapping[:to]

          if from.is_a?(Regexp)
            return location.gsub(from, to) if location&.match?(from)
          elsif location == from
            return to
          end
        end

        nil
      end

      # Rewrite schemaLocation attributes to use flattened package structure
      # @param xsd_files [Hash] Map of source paths to package paths
      # @param repository [SchemaRepository] Repository with schema mappings
      def rewrite_schema_locations(xsd_files, repository)
        # Build reverse mapping: abs_path -> package_basename
        path_to_basename = {}
        xsd_files.each do |abs_path, package_path|
          basename = File.basename(package_path)
          path_to_basename[abs_path] = basename
        end

        # Build mapping from HTTP URLs to package basenames
        # by checking processed_schemas
        url_to_basename = {}
        all_schemas = repository.all_schemas
        glob_mappings = (repository.schema_location_mappings || []).map(&:to_glob_format)

        all_schemas.each_key do |schema_location|
          # For HTTP URLs, resolve to file path and map to basename
          next unless schema_location.start_with?("http://", "https://")

          resolved_path = resolve_schema_location(schema_location,
                                                  glob_mappings)
          if resolved_path && path_to_basename.key?(File.absolute_path(resolved_path))
            url_to_basename[schema_location] =
              path_to_basename[File.absolute_path(resolved_path)]
          end
        end

        # Rewrite each file's schemaLocation attributes
        # Use transform_keys to get both key and value in the block
        rewritten_files = {}
        xsd_files.each do |source_path, package_path|
          content = File.read(source_path)
          rewritten_content = rewrite_file_content(
            content,
            source_path,
            path_to_basename,
            url_to_basename,
          )
          rewritten_files[source_path] = {
            package_path: package_path,
            content: rewritten_content,
          }
        end

        # Replace xsd_files with rewritten version
        xsd_files.replace(rewritten_files)
      end

      # Rewrite schemaLocation attributes in XSD content
      # @param content [String] Original XSD content
      # @param source_path [String] Source file path for resolving relatives
      # @param path_mapping [Hash] Map of abs paths to package basenames
      # @param url_to_basename [Hash] Map of HTTP URLs to package basenames
      # @return [String] Rewritten content
      def rewrite_file_content(content, source_path, path_mapping,
url_to_basename)
        source_dir = File.dirname(File.absolute_path(source_path))

        # Rewrite import schemaLocation (with or without xs: prefix)
        content = content.gsub(/<(xs:)?import([^>]*)schemaLocation="([^"]+)"/) do
          prefix = Regexp.last_match(1) || ""
          attrs = Regexp.last_match(2)
          location = Regexp.last_match(3)
          new_location = resolve_to_package_location(
            location,
            source_dir,
            path_mapping,
            url_to_basename,
          )
          %(<#{prefix}import#{attrs}schemaLocation="#{new_location}")
        end

        # Rewrite include schemaLocation (with or without xs: prefix)
        content.gsub(/<(xs:)?include([^>]*)schemaLocation="([^"]+)"/) do
          prefix = Regexp.last_match(1) || ""
          attrs = Regexp.last_match(2)
          location = Regexp.last_match(3)
          new_location = resolve_to_package_location(
            location,
            source_dir,
            path_mapping,
            url_to_basename,
          )
          %(<#{prefix}include#{attrs}schemaLocation="#{new_location}")
        end
      end

      # Resolve a schemaLocation to its package location
      # @param location [String] Original schemaLocation value
      # @param source_dir [String] Directory of the source file
      # @param path_mapping [Hash] Map of abs paths to package basenames
      # @param url_to_basename [Hash] Map of HTTP URLs to package basenames
      # @return [String] New location (just the basename)
      def resolve_to_package_location(location, source_dir, path_mapping,
url_to_basename)
        # For HTTP URLs, check the url_to_basename mapping
        if location.start_with?("http://", "https://")
          return url_to_basename[location] if url_to_basename.key?(location)

          # If not in mapping, keep original URL (external dependency)
          return location
        end

        # Resolve relative path to absolute
        abs_location = File.absolute_path(File.join(source_dir, location))

        # Look up in mapping
        path_mapping[abs_location] || File.basename(location)
      end
    end
  end
end
