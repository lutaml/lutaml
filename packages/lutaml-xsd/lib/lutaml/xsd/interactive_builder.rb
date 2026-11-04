# frozen_string_literal: true

require "tty-prompt"
require "yaml"
require "fileutils"
require "digest"
require "net/http"
require "uri"

module Lutaml
  module Xsd
    # Interactive package builder for creating schema repository configurations
    # Discovers dependencies, resolves ambiguities, and generates YAML config
    class InteractiveBuilder
      attr_reader :entry_points, :options, :prompt, :resolved_mappings,
                  :namespace_mappings, :pattern_mappings, :pending_schemas, :processed_schemas

      SESSION_FILE = ".lutaml-xsd-session.yml"
      CACHE_DIR = File.expand_path("~/.lutaml-xsd/cache")

      def initialize(entry_points, options = {})
        @entry_points = entry_points
        @options = options
        @prompt = TTY::Prompt.new
        @resolved_mappings = []
        @namespace_mappings = []
        @pattern_mappings = []
        @pending_schemas = []
        @processed_schemas = []
        @dependency_count = 0
      end

      # Run the interactive builder session
      # @return [Boolean] Success status
      def run
        display_welcome

        if options[:resume] && session_exists?
          load_session
        else
          initialize_session
        end

        process_all_schemas
        save_configuration
        cleanup_session

        display_summary
        true
      rescue StandardError => e
        error("Interactive builder failed: #{e.message}")
        save_session if @dependency_count.positive?
        false
      end

      private

      # Display welcome message
      def display_welcome
        output "═" * 80
        output "Lutaml XSD Interactive Package Builder"
        output "═" * 80
        output ""
        output "Entry points: #{entry_points.join(', ')}"
        output "Search paths: #{search_paths.join(', ')}" if search_paths.any?
        output ""
      end

      # Initialize a new session
      def initialize_session
        entry_points.each do |entry_point|
          unless File.exist?(entry_point)
            error "Entry point not found: #{entry_point}"
            next
          end
          @pending_schemas << { path: entry_point, source: nil, type: "entry" }
        end
      end

      # Process all schemas in the pending queue
      def process_all_schemas
        while @pending_schemas.any?
          schema_info = @pending_schemas.shift
          process_schema(schema_info)
        end
      end

      # Process a single schema file
      # @param schema_info [Hash] Schema information
      def process_schema(schema_info)
        path = schema_info[:path]

        return if @processed_schemas.include?(path)

        @processed_schemas << path

        verbose_output "Processing: #{path}"

        schema = parse_schema(path)
        return unless schema

        extract_namespace_mappings(schema, path)
        discover_dependencies(schema, path)
      end

      # Parse an XSD schema file
      # @param path [String] Path to schema file
      # @return [Schema, nil] Parsed schema or nil on error
      def parse_schema(path)
        # Parse without location/schema_mappings to avoid automatic dependency resolution
        # We want to discover dependencies ourselves interactively
        Lutaml::Xml::Schema::Xsd.parse(File.read(path))
      rescue StandardError => e
        verbose_output "Warning: Could not parse #{path}: #{e.message}"
        nil
      end

      # Extract namespace mappings from schema
      # @param schema [Schema] Parsed schema
      # @param path [String] Schema file path
      def extract_namespace_mappings(schema, path)
        return unless schema.target_namespace

        # Add target namespace if not already present
        return if namespace_exists?(schema.target_namespace)

        prefix = derive_namespace_prefix(schema, path)
        @namespace_mappings << {
          "prefix" => prefix,
          "uri" => schema.target_namespace,
        }
        verbose_output "  Namespace: #{prefix} → #{schema.target_namespace}"
      end

      # Discover dependencies (imports and includes) in schema
      # @param schema [Schema] Parsed schema
      # @param source_path [String] Path to source schema
      def discover_dependencies(schema, source_path)
        # Use plural 'imports' and 'includes' to get raw Import/Include objects
        # These are populated even without location/schema_mappings context

        # Process imports
        schema.imports.each do |import_obj|
          process_dependency(import_obj, source_path, "import")
        end

        # Process includes
        schema.includes.each do |include_obj|
          process_dependency(include_obj, source_path, "include")
        end
      end

      # Process a single dependency (import or include)
      # @param dependency [Import, Include] Dependency object
      # @param source_path [String] Source schema path
      # @param type [String] Dependency type ("import" or "include")
      def process_dependency(dependency, source_path, type)
        return if dependency.nil?

        @dependency_count += 1

        schema_location = dependency.schema_path
        namespace = type == "import" ? dependency.namespace : nil

        display_dependency_header(@dependency_count, source_path, type,
                                  schema_location, namespace)

        if schema_location.nil? || schema_location.empty?
          handle_missing_schema_location(namespace, source_path)
        elsif url?(schema_location)
          handle_url_schema(schema_location, namespace)
        else
          handle_local_schema(schema_location, namespace, source_path)
        end

        output ""
      end

      # Display dependency resolution header
      def display_dependency_header(number, source, type, location, namespace)
        output "═" * 80
        output "Resolving dependency ##{number}"
        output "─" * 80
        output "Source schema:    #{File.basename(source)}"
        output "Dependency type:  <xs:#{type}>"
        output "Namespace:        #{namespace || '(same as parent)'}" if type == "import"
        output "schemaLocation:   #{location || '⚠️  NOT SPECIFIED'}"
        output ""
      end

      # Handle missing schemaLocation attribute
      # @param namespace [String, nil] Namespace URI
      # @param source_path [String] Source schema path
      def handle_missing_schema_location(namespace, source_path)
        output "⚠️  Missing schemaLocation attribute!"
        output ""

        choices = [
          { name: "Provide local file path", value: :local },
          { name: "Try namespace URI as URL", value: :namespace_url },
          { name: "Skip", value: :skip },
        ]

        choice = prompt.select("Select action:", choices)

        case choice
        when :local
          path = prompt.ask("Enter path to local file:")
          if File.exist?(path)
            add_namespace_mapping(namespace, path)
            queue_schema(path, source_path, "namespace")
          else
            error "File not found: #{path}"
          end
        when :namespace_url
          handle_url_schema(namespace, namespace) if namespace
        when :skip
          verbose_output "Skipped"
        end
      end

      # Handle URL-based schema location
      # @param url [String] URL to schema
      # @param namespace [String, nil] Namespace URI
      def handle_url_schema(url, namespace)
        if options[:local]
          handle_url_local_mode(url, namespace)
        elsif options[:no_fetch]
          handle_url_no_fetch(url, namespace)
        else
          handle_url_auto_fetch(url, namespace)
        end
      end

      # Handle URL in local-only mode
      def handle_url_local_mode(url, _namespace)
        output "⚠️  URL reference in --local mode"
        output ""

        choices = [
          { name: "Provide local file path", value: :local },
          { name: "Skip (mark as external)", value: :skip },
        ]

        choice = prompt.select("Select action:", choices)

        return unless choice == :local

        path = prompt.ask("Enter path to local file:")
        if File.exist?(path)
          add_mapping(url, path, "user provided")
          queue_schema(path, url, "url")
        else
          error "File not found: #{path}"
        end
      end

      # Handle URL with --no-fetch option
      def handle_url_no_fetch(url, namespace)
        output "Automatic fetching disabled (--no-fetch)"
        output ""

        choices = [
          { name: "Provide local file path", value: :local },
          { name: "Provide alternative URL", value: :alt_url },
          { name: "Skip", value: :skip },
        ]

        choice = prompt.select("Select action:", choices)

        case choice
        when :local
          path = prompt.ask("Enter path to local file:")
          if File.exist?(path)
            add_mapping(url, path, "user provided")
            queue_schema(path, url, "url")
          else
            error "File not found: #{path}"
          end
        when :alt_url
          alt_url = prompt.ask("Enter alternative URL:")
          handle_url_auto_fetch(alt_url, namespace)
        end
      end

      # Handle URL with automatic fetching
      def handle_url_auto_fetch(url, namespace)
        output "Attempting to download..."

        cached_path = fetch_url(url)

        if cached_path
          output "✓ Downloaded to cache: #{cached_path}"
          add_mapping(url, cached_path, "auto-fetched")
          queue_schema(cached_path, url, "url")
        else
          handle_url_fetch_failure(url, namespace)
        end
      end

      # Handle failed URL fetch
      def handle_url_fetch_failure(url, namespace)
        output "✗ Failed to fetch schema"
        output ""

        choices = [
          { name: "Provide local file path", value: :local },
          { name: "Provide alternative URL", value: :alt_url },
          { name: "Retry download", value: :retry },
          { name: "Skip", value: :skip },
        ]

        choice = prompt.select("Select action:", choices)

        case choice
        when :local
          path = prompt.ask("Enter path to local file:")
          if File.exist?(path)
            add_mapping(url, path, "user provided")
            queue_schema(path, url, "url")
          else
            error "File not found: #{path}"
          end
        when :alt_url
          alt_url = prompt.ask("Enter alternative URL:")
          handle_url_auto_fetch(alt_url, namespace)
        when :retry
          handle_url_auto_fetch(url, namespace)
        end
      end

      # Handle local schema file resolution
      # @param location [String] Schema location (relative path)
      # @param namespace [String, nil] Namespace URI
      # @param source_path [String] Source schema path
      def handle_local_schema(location, namespace, source_path)
        # Check for pattern matches first
        if (pattern_match = find_pattern_match(location))
          resolved_path = apply_pattern(location, pattern_match)
          output "✓ Matched pattern: #{pattern_match[:from]}"
          output "  Resolved to: #{resolved_path}"
          queue_schema(resolved_path, source_path, "pattern")
          return
        end

        # Search for matching files
        matches = search_for_schema(location)

        case matches.size
        when 0
          handle_no_matches(location, namespace, source_path)
        when 1
          handle_unique_match(location, matches.first, source_path)
        else
          handle_multiple_matches(location, matches, source_path)
        end
      end

      # Search for schema files matching the location
      # @param location [String] Schema location pattern
      # @return [Array<String>] Matching file paths
      def search_for_schema(location)
        basename = File.basename(location)
        matches = []

        search_paths.each do |search_path|
          pattern = File.join(search_path, "**", basename)
          Dir.glob(pattern).each do |match|
            matches << File.expand_path(match)
          end
        end

        matches.uniq
      end

      # Handle case where no matching files are found
      def handle_no_matches(location, namespace, source_path)
        output "⚠️  No matches found in search paths"
        output ""

        choices = [
          { name: "Provide local file path", value: :local },
          { name: "Add additional search path", value: :add_path },
          { name: "Skip", value: :skip },
        ]

        choice = prompt.select("Select action:", choices)

        case choice
        when :local
          path = prompt.ask("Enter path to local file:")
          if File.exist?(path)
            add_mapping(location, path, "user provided")
            queue_schema(path, source_path, "manual")
          else
            error "File not found: #{path}"
          end
        when :add_path
          new_path = prompt.ask("Enter search path (supports **):")
          search_paths << new_path
          output "✓ Added search path: #{new_path}"
          output "Searching again..."
          matches = search_for_schema(location)
          if matches.any?
            handle_local_schema(location, namespace, source_path)
          else
            output "Still no matches found"
          end
        end
      end

      # Handle case where exactly one match is found
      def handle_unique_match(location, match, source_path)
        output "Found 1 match: #{match}"
        output ""
        output "✓ Auto-resolved (unique match)"
        add_mapping(location, match, "unique match")
        queue_schema(match, source_path, "auto")

        # Check for pattern opportunity
        check_pattern_opportunity(location, match)
      end

      # Handle case where multiple matches are found
      def handle_multiple_matches(location, matches, source_path)
        output "⚠️  AMBIGUOUS: Found #{matches.size} matches"
        output ""

        choices = matches.map.with_index do |match, i|
          stat = File.stat(match)
          {
            name: format_file_choice(match, stat, i + 1),
            value: match,
          }
        end

        choices << { name: "Enter custom path", value: :custom }
        choices << { name: "Skip for now", value: :skip }

        choice = prompt.select("Please select the correct file:", choices)

        case choice
        when :custom
          path = prompt.ask("Enter path to local file:")
          if File.exist?(path)
            add_mapping(location, path, "user selected")
            queue_schema(path, source_path, "manual")
            check_pattern_opportunity(location, path)
          else
            error "File not found: #{path}"
          end
        when :skip
          verbose_output "Skipped"
        else
          add_mapping(location, choice, "user selected")
          queue_schema(choice, source_path, "manual")
          check_pattern_opportunity(location, choice)
        end
      end

      # Format a file choice for display
      # @param path [String] File path
      # @param stat [File::Stat] File statistics
      # @param number [Integer] Choice number
      # @return [String] Formatted choice string
      def format_file_choice(path, stat, number)
        size = format_file_size(stat.size)
        mtime = stat.mtime.strftime("%Y-%m-%d %H:%M:%S")
        "[#{number}] #{path}\n    Modified: #{mtime}\n    Size: #{size}"
      end

      # Format file size for display
      # @param size [Integer] Size in bytes
      # @return [String] Formatted size
      def format_file_size(size)
        if size < 1024
          "#{size} B"
        elsif size < 1024 * 1024
          "#{(size / 1024.0).round(1)} KB"
        else
          "#{(size / (1024.0 * 1024)).round(1)} MB"
        end
      end

      # Check if a pattern mapping opportunity exists
      # @param location [String] Schema location
      # @param resolved_path [String] Resolved file path
      def check_pattern_opportunity(location, resolved_path)
        return if location.include?("://") # Skip URLs

        # Extract directory pattern
        location_dir = File.dirname(location)
        return if location_dir == "."

        # Check if we can create a useful pattern
        return unless location_dir.include?("../") || location_dir.include?("/")

        suggest_pattern(location, resolved_path)
      end

      # Suggest creating a pattern mapping
      # @param location [String] Schema location
      # @param resolved_path [String] Resolved file path
      def suggest_pattern(location, resolved_path)
        output ""
        output "Pattern opportunity detected!"

        pattern_from = create_pattern_from_location(location)
        pattern_to = create_pattern_from_resolved(resolved_path, location)

        output "  From: #{pattern_from}"
        output "  To:   #{pattern_to}"
        output ""

        return unless prompt.yes?("Create this pattern mapping?")

        @pattern_mappings << {
          "from" => pattern_from,
          "to" => pattern_to,
          "pattern" => true,
        }
        output "✓ Pattern created"
      end

      # Create a regex pattern from schema location
      # @param location [String] Schema location
      # @return [String] Regex pattern
      def create_pattern_from_location(location)
        dir = File.dirname(location)
        # Escape special regex characters and replace .. paths with pattern
        pattern = dir.gsub("../", '(?:\\.\\./)+')
        pattern = Regexp.escape(pattern).gsub('\\(\\.\\.\\/\\)\\+',
                                              '(?:\\\\.\\\\./)+')
        "#{pattern}/(.+\\.xsd)$"
      end

      # Create a replacement pattern from resolved path
      # @param resolved_path [String] Resolved file path
      # @param original_location [String] Original location
      # @return [String] Replacement pattern
      def create_pattern_from_resolved(resolved_path, _original_location)
        dir = File.dirname(resolved_path)
        "#{dir}/\\1"
      end

      # Find a matching pattern for a location
      # @param location [String] Schema location
      # @return [Hash, nil] Matching pattern or nil
      def find_pattern_match(location)
        @pattern_mappings.find do |pattern|
          pattern["pattern"] && location =~ /#{pattern['from']}/
        end
      end

      # Apply a pattern to a location
      # @param location [String] Schema location
      # @param pattern [Hash] Pattern mapping
      # @return [String] Resolved path
      def apply_pattern(location, pattern)
        location.gsub(/#{pattern['from']}/, pattern["to"])
      end

      # Add a schema location mapping
      # @param from [String] Original location
      # @param to [String] Resolved path
      # @param reason [String] Reason for mapping
      def add_mapping(from, to, reason)
        @resolved_mappings << {
          "from" => from,
          "to" => to,
          "comment" => "Found by: #{reason}",
        }
        output "✓ Mapping saved:"
        output "  #{from} → #{to}"
      end

      # Add a namespace-based mapping
      # @param namespace [String] Namespace URI
      # @param path [String] Resolved path
      def add_namespace_mapping(namespace, path)
        add_mapping("(namespace: #{namespace})", path, "namespace-based")
      end

      # Queue a schema for processing
      # @param path [String] Schema file path
      # @param source [String] Source that referenced this schema
      # @param type [String] Discovery type
      def queue_schema(path, source, type)
        return if @processed_schemas.include?(path)
        return if @pending_schemas.any? { |s| s[:path] == path }

        @pending_schemas << {
          path: path,
          source: source,
          type: type,
        }
        verbose_output "  Queued for processing: #{path}"
      end

      # Check if namespace already exists in mappings
      # @param uri [String] Namespace URI
      # @return [Boolean] True if exists
      def namespace_exists?(uri)
        @namespace_mappings.any? { |ns| ns["uri"] == uri }
      end

      # Derive a namespace prefix from schema
      # @param schema [Schema] Parsed schema
      # @param path [String] Schema file path
      # @return [String] Namespace prefix
      def derive_namespace_prefix(_schema, path)
        # Try to extract from xmlns declarations
        # For now, use a simple heuristic based on filename or namespace
        basename = File.basename(path, ".xsd")
        basename.gsub(/[^a-zA-Z0-9]/, "").downcase
      end

      # Fetch a URL and cache it
      # @param url [String] URL to fetch
      # @return [String, nil] Path to cached file or nil on failure
      def fetch_url(url)
        timeout = options[:fetch_timeout] || 30

        uri = URI.parse(url)
        cache_key = Digest::SHA256.hexdigest(url)[0..5]
        cache_path = File.join(CACHE_DIR, cache_key)
        FileUtils.mkdir_p(cache_path)

        filename = File.basename(uri.path).empty? ? "schema.xsd" : File.basename(uri.path)
        cached_file = File.join(cache_path, filename)

        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                            open_timeout: timeout, read_timeout: timeout) do |http|
          request = Net::HTTP::Get.new(uri.request_uri)
          response = http.request(request)

          if response.code == "200"
            File.write(cached_file, response.body)
            return cached_file
          end
        end

        nil
      rescue StandardError => e
        verbose_output "  Fetch error: #{e.message}"
        nil
      end

      # Save the configuration to YAML file
      def save_configuration
        output_path = options[:output] || "repository.yml"

        config = {
          "# Auto-generated by lutaml-xsd package init" => nil,
          "# Date" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
          "# Entry points" => entry_points.join(", "),
          "files" => entry_points,
          "schema_location_mappings" => @resolved_mappings + @pattern_mappings,
          "namespace_mappings" => @namespace_mappings,
        }

        # Remove nil keys (comments)
        config.to_yaml
        yaml_str = "# Auto-generated by lutaml-xsd package init\n" \
                   "# Date: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}\n" \
                   "# Entry points: #{entry_points.join(', ')}\n\n" \
                   "files:\n" + entry_points.map { |f|
                                  "  - #{f}"
                                }.join("\n") + "\n\n" \
                                               "schema_location_mappings:\n" + format_mappings_yaml(@resolved_mappings + @pattern_mappings) + "\n\n" \
                                                                                                                                              "namespace_mappings:\n" + format_namespace_mappings_yaml(@namespace_mappings)

        File.write(output_path, yaml_str)

        output ""
        output "═" * 80
        output "✓ Configuration saved: #{output_path}"
      end

      # Format mappings as YAML string
      # @param mappings [Array<Hash>] Schema location mappings
      # @return [String] Formatted YAML
      def format_mappings_yaml(mappings)
        mappings.map do |mapping|
          lines = []
          lines << "  - from: #{mapping['from'].inspect}"
          lines << "    to: #{mapping['to']}"
          lines << "    pattern: true" if mapping["pattern"]
          lines << "    # #{mapping['comment']}" if mapping["comment"]
          lines.join("\n")
        end.join("\n")
      end

      # Format namespace mappings as YAML string
      # @param mappings [Array<Hash>] Namespace mappings
      # @return [String] Formatted YAML
      def format_namespace_mappings_yaml(mappings)
        mappings.map do |mapping|
          "  - prefix: #{mapping['prefix']}\n    uri: #{mapping['uri'].inspect}"
        end.join("\n")
      end

      # Save session state for resume
      def save_session
        session_data = {
          "entry_points" => entry_points,
          "options" => options,
          "resolved_mappings" => @resolved_mappings,
          "namespace_mappings" => @namespace_mappings,
          "pattern_mappings" => @pattern_mappings,
          "pending_schemas" => @pending_schemas,
          "processed_schemas" => @processed_schemas,
          "dependency_count" => @dependency_count,
        }

        File.write(SESSION_FILE, session_data.to_yaml)
        verbose_output "Session saved"
      end

      # Load session state from file
      def load_session
        return unless File.exist?(SESSION_FILE)

        session_data = YAML.load_file(SESSION_FILE)
        @resolved_mappings = session_data["resolved_mappings"] || []
        @namespace_mappings = session_data["namespace_mappings"] || []
        @pattern_mappings = session_data["pattern_mappings"] || []
        @pending_schemas = session_data["pending_schemas"] || []
        @processed_schemas = session_data["processed_schemas"] || []
        @dependency_count = session_data["dependency_count"] || 0

        output "✓ Resumed previous session"
        output "  Resolved: #{@resolved_mappings.size} mappings"
        output "  Pending: #{@pending_schemas.size} schemas"
        output ""
      end

      # Check if session file exists
      # @return [Boolean]
      def session_exists?
        File.exist?(SESSION_FILE)
      end

      # Clean up session file
      def cleanup_session
        FileUtils.rm_f(SESSION_FILE)
      end

      # Display final summary
      def display_summary
        output "═" * 80
        output "Summary:"
        output "  Dependencies processed: #{@dependency_count}"
        output "  Schemas resolved: #{@processed_schemas.size}"
        output "  Schema mappings: #{@resolved_mappings.size}"
        output "  Pattern mappings: #{@pattern_mappings.size}"
        output "  Namespace mappings: #{@namespace_mappings.size}"
        output "═" * 80
      end

      # Get search paths from options
      # @return [Array<String>] Search paths
      def search_paths
        @search_paths ||= (options[:search_paths] || []).flat_map do |path|
          path.end_with?("**") ? path : File.join(path, "**")
        end
      end

      # Check if a string is a URL
      # @param str [String] String to check
      # @return [Boolean] True if URL
      def url?(str)
        str.to_s.start_with?("http://", "https://")
      end

      # Output a message
      # @param message [String] Message to output
      def output(message)
        puts message
      end

      # Output verbose message
      # @param message [String] Message to output
      def verbose_output(message)
        output message if options[:verbose]
      end

      # Output error message
      # @param message [String] Error message
      def error(message)
        warn "ERROR: #{message}"
      end
    end
  end
end
