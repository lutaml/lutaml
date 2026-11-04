# frozen_string_literal: true

require "yaml"
require "zip"
require "lutaml/store"
require_relative "errors"

module Lutaml
  module Xsd
    # A fully resolved, validated, searchable collection of XSD schemas
    # Provides namespace-aware type resolution across multiple schemas
    class SchemaRepository < Lutaml::Model::Serializable
      # Serializable attributes
      attribute :files, :string, collection: true
      attribute :base_packages, BasePackageConfig, collection: true
      attribute :schema_location_mappings, SchemaLocationMapping,
                collection: true
      attribute :namespace_mappings, NamespaceMapping, collection: true
      attribute :output_package, :string

      yaml do
        map "files", to: :files
        map "base_packages", to: :base_packages
        map "schema_location_mappings", to: :schema_location_mappings
        map "namespace_mappings", to: :namespace_mappings
        map "output_package", to: :output_package
      end

      # Override base_packages setter to handle mixed types
      def base_packages=(value)
        @base_packages = value
      end

      # Override base_packages getter to ensure array
      def base_packages
        @base_packages || []
      end

      # Internal state (not serialized)
      attr_reader :lazy_load

      def initialize(**attributes)
        # Initialize internal state first
        @parsed_schemas = Lutaml::Store::BasicStore.new(adapter_type: :memory)
        @namespace_registry = NamespaceRegistry.new
        @type_index = TypeIndex.new
        @lazy_load = true
        @resolved = false
        @validated = false
        @verbose = false

        # Call super to set attributes from Lutaml::Model::Serializable
        super

        # Register namespace mappings AFTER super sets the attributes
        # This ensures they're available immediately when loading from packages
        return unless namespace_mappings && !namespace_mappings.empty?

        namespace_mappings.each do |mapping|
          namespace_registry.register(mapping.prefix, mapping.uri)
        end
      end

      # Some lutaml-model deserialization paths construct instances
      # without running the custom initialize, so every piece of
      # internal state is nil-safe at the read boundary (#175: a
      # dependent-lane bundle hit "undefined method 'exists?' for
      # nil" from these being uninitialized).
      def parsed_schemas
        @parsed_schemas ||= Lutaml::Store::BasicStore.new(adapter_type: :memory)
      end

      def namespace_registry
        @namespace_registry ||= NamespaceRegistry.new
      end

      def type_index
        @type_index ||= TypeIndex.new
      end

      # Parse XSD schemas from configured files and base packages
      # @param schema_locations [Hash] Additional schema location mappings
      # @param lazy_load [Boolean] Whether to lazy load imported schemas
      # @param verbose [Boolean] Whether to show progress indicators
      # @return [self]
      def parse(schema_locations: {}, lazy_load: true, verbose: false)
        @lazy_load = lazy_load
        @verbose = verbose

        # Register namespace mappings loaded from YAML with the namespace registry
        if namespace_mappings && !namespace_mappings.empty?
          namespace_mappings.each do |mapping|
            namespace_registry.register(mapping.prefix, mapping.uri)
          end
        end

        # Convert schema_location_mappings to Glob format
        glob_mappings = (schema_location_mappings || []).map(&:to_glob_format)

        # Add any additional schema locations
        if schema_locations && !schema_locations.empty?
          schema_locations.each do |from, to|
            glob_mappings << { from: from, to: to }
          end
        end

        # Load base packages first - auto-detect which method to use
        if base_packages&.any?
          if supports_conflict_detection?
            load_base_packages_with_conflict_detection(glob_mappings)
          else
            load_base_packages(glob_mappings)
          end
        end

        # Parse each schema file with progress indicators
        if @verbose
          puts "Parsing #{(files || []).size} schema files..."
          (files || []).each_with_index do |file_path, idx|
            print "\r[#{idx + 1}/#{(files || []).size}] #{File.basename(file_path)}"
            $stdout.flush
            parse_schema_file(file_path, glob_mappings)
          end
          puts "\n✓ All schemas parsed"
        else
          (files || []).each do |file_path|
            parse_schema_file(file_path, glob_mappings)
          end
        end

        self
      end

      # Force full resolution of all imports/includes and build indexes
      # @param verbose [Boolean] Whether to show progress indicators
      # @return [self]
      def resolve(verbose: false)
        return self if @resolved

        @verbose = verbose

        # Get all processed schemas including imports/includes
        all_schemas = self.all_schemas

        if @verbose
          total_imports = count_total_imports(all_schemas)
          if total_imports.positive?
            puts "Resolving #{total_imports} schema dependencies..."

            processed = 0
            all_schemas.each_value do |schema|
              imports = schema.import
              (imports || []).each do |import|
                processed += 1
                namespace_info = import.namespace || "no namespace"
                print "\r[#{processed}/#{total_imports}] #{namespace_info}"
                $stdout.flush
              end
            end
            puts "\n✓ All dependencies resolved"
          else
            puts "✓ No schema dependencies to resolve"
          end
        end

        # Extract namespaces from parsed schemas if not configured
        if namespace_mappings.nil? || namespace_mappings.empty?
          namespace_registry.extract_from_schemas(all_schemas.values)
        else
          # Register namespace mappings from configuration
          namespace_mappings.each do |mapping|
            namespace_registry.register(mapping.prefix, mapping.uri)
          end
        end

        # Build type index from all parsed schemas (including imported/included)
        type_index.build_from_schemas(all_schemas)

        @resolved = true
        self
      end

      # Validate the repository
      # @param strict [Boolean] Whether to fail on first error or collect all
      # @return [Array<String>] List of validation errors (empty if valid)
      def validate(strict: false)
        errors = []

        # Check that all files exist and are accessible
        (files || []).each do |file_path|
          next if File.exist?(file_path)

          error = "Schema file not found: #{file_path}"
          errors << error
          raise Error, error if strict
        end

        # Check that all schemas were parsed successfully
        missing_schemas = (files || []).reject { |f| parsed_schemas.exists?(f) }
        unless missing_schemas.empty?
          error = "Failed to parse schemas: #{missing_schemas.join(', ')}"
          errors << error
          raise Error, error if strict
        end

        # Check for circular imports (simple check)
        check_circular_imports(errors, strict)

        # Check that namespace mappings are valid
        (namespace_mappings || []).each do |mapping|
          if mapping.prefix.nil? || mapping.prefix.empty?
            error = "Invalid namespace mapping: prefix cannot be empty"
            errors << error
            raise Error, error if strict
          end
          next unless mapping.uri.nil? || mapping.uri.empty?

          error = "Invalid namespace mapping for prefix '#{mapping.prefix}': URI cannot be empty"
          errors << error
          raise Error, error if strict
        end

        @validated = errors.empty?
        errors
      end

      # Configure a single namespace prefix mapping
      # @param prefix [String] The namespace prefix (e.g., "gml")
      # @param uri [String] The namespace URI
      # @return [self]
      def configure_namespace(prefix:, uri:)
        @namespace_mappings ||= []
        @namespace_mappings << NamespaceMapping.new(prefix: prefix, uri: uri)
        namespace_registry.register(prefix, uri)
        self
      end

      # Configure multiple namespace prefix mappings
      # @param mappings [Hash, Array] Prefix-to-URI mappings
      # @return [self]
      def configure_namespaces(mappings)
        case mappings
        when Hash
          mappings.each do |prefix, uri|
            configure_namespace(prefix: prefix, uri: uri)
          end
        when Array
          mappings.each do |mapping|
            if mapping.is_a?(NamespaceMapping)
              configure_namespace(prefix: mapping.prefix, uri: mapping.uri)
            elsif mapping.is_a?(Hash)
              prefix = mapping[:prefix] || mapping["prefix"]
              uri = mapping[:uri] || mapping["uri"]
              configure_namespace(prefix: prefix, uri: uri)
            end
          end
        end
        self
      end

      # Resolve a qualified type name to its definition
      # @param qname [String] Qualified name (e.g., "gml:CodeType", "{http://...}CodeType")
      # @return [TypeResolutionResult]
      def find_type(qname)
        resolution_path = [qname]

        # Parse the qualified name
        parsed = QualifiedNameParser.parse(qname, namespace_registry)
        unless parsed
          return TypeResolutionResult.failure(
            qname: qname,
            error_message: "Failed to parse qualified name: #{qname}",
            resolution_path: resolution_path,
          )
        end

        namespace = parsed[:namespace]
        local_name = parsed[:local_name]

        # Add Clark notation to resolution path
        clark_notation = QualifiedNameParser.to_clark_notation(parsed)
        resolution_path << clark_notation if clark_notation != qname

        # Check if namespace was resolved for prefixed names
        # For unprefixed names, namespace can be nil and that's valid
        if parsed[:prefix] && !namespace
          return TypeResolutionResult.failure(
            qname: qname,
            local_name: local_name,
            error_message: "Namespace prefix '#{parsed[:prefix]}' not registered",
            resolution_path: resolution_path,
          )
        end

        # Look up type in index
        type_info = type_index.find_by_namespace_and_name(namespace,
                                                          local_name)

        if type_info
          resolution_path << "#{type_info[:schema_file]}##{local_name}"

          TypeResolutionResult.success(
            qname: qname,
            namespace: namespace,
            local_name: local_name,
            definition: type_info[:definition],
            schema_file: type_info[:schema_file],
            resolution_path: resolution_path,
          )
        else
          # Provide suggestions for similar types
          suggestions = type_index.suggest_similar(namespace, local_name)
          suggestion_text = suggestions.empty? ? "" : " Did you mean: #{suggestions.join(', ')}?"

          TypeResolutionResult.failure(
            qname: qname,
            namespace: namespace,
            local_name: local_name,
            error_message: "Type '#{local_name}' not found in namespace '#{namespace}'.#{suggestion_text}",
            resolution_path: resolution_path,
          )
        end
      end

      # Find an attribute definition by qualified name
      # Searches across all schemas in the repository
      # @param qualified_name [String] Qualified attribute name (e.g., "xml:id")
      # @return [Attribute, nil] The attribute definition or nil if not found
      def find_attribute(qualified_name)
        # Parse the qualified name
        parsed = QualifiedNameParser.parse(qualified_name, namespace_registry)
        return nil unless parsed

        namespace_uri = parsed[:namespace]
        local_name = parsed[:local_name]

        # Look up attribute in the type index
        attr_info = type_index.find_by_namespace_and_name(namespace_uri,
                                                          local_name)

        # Return the definition if it's an attribute
        return unless attr_info && attr_info[:type] == :attribute

        attr_info[:definition]
      end

      # Find an element definition by qualified name
      # Searches across all schemas in the repository
      # @param qualified_name [String] Qualified element name (e.g., "gml:FeatureCollection")
      # @return [Element, nil] The element definition or nil if not found
      def find_element(qualified_name)
        # Parse the qualified name
        parsed = parse_qualified_name(qualified_name)
        return nil unless parsed

        namespace_uri = parsed[:namespace]
        local_name = parsed[:local_name]

        # Get all processed schemas (including those from loaded packages)
        all_schemas = self.all_schemas

        # Search all schemas
        all_schemas.each_value do |schema|
          # For unprefixed names (namespace_uri is nil), search in all namespaces
          # For prefixed names, only search in matching namespace
          next if namespace_uri && schema.target_namespace != namespace_uri

          # Search in top-level elements
          elements = schema.element
          elements = [elements] unless elements.is_a?(Array)
          elem = elements.compact.find { |e| e.name == local_name }
          return elem if elem
        end

        nil
      end

      # Find a group definition by qualified name
      # Searches across all schemas in the repository
      # @param qualified_name [String] Qualified group name
      # @return [Group, nil] The group definition or nil if not found
      def find_group(qualified_name)
        parsed = parse_qualified_name(qualified_name)
        return nil unless parsed

        namespace_uri = parsed[:namespace]
        local_name = parsed[:local_name]

        # Get all processed schemas (including those from loaded packages)
        all_schemas = self.all_schemas

        all_schemas.each_value do |schema|
          next unless schema.target_namespace == namespace_uri

          grp = schema.group.find { |g| g.name == local_name }
          return grp if grp
        end

        nil
      end

      # Find an attribute group definition by qualified name
      # Searches across all schemas in the repository
      # @param qualified_name [String] Qualified attribute group name
      # @return [AttributeGroup, nil] The attribute group definition or nil if not found
      def find_attribute_group(qualified_name)
        parsed = parse_qualified_name(qualified_name)
        return nil unless parsed

        namespace_uri = parsed[:namespace]
        local_name = parsed[:local_name]

        # Get all processed schemas (including those from loaded packages)
        all_schemas = self.all_schemas

        all_schemas.each_value do |schema|
          next unless schema.target_namespace == namespace_uri

          ag = schema.attribute_group.find { |g| g.name == local_name }
          return ag if ag
        end

        nil
      end

      # Parse a qualified name into its components
      # @param qualified_name [String] The qualified name to parse
      # @return [Hash, nil] Parsed components with :prefix, :namespace,
      #   :local_name
      def parse_qualified_name(qualified_name)
        QualifiedNameParser.parse(qualified_name, namespace_registry)
      end

      # Get repository statistics
      # @return [Hash] Statistics about the repository
      def statistics
        type_stats = type_index.statistics

        {
          total_schemas: parsed_schemas.size,
          total_types: type_stats[:total_types],
          types_by_category: type_stats[:by_type],
          total_namespaces: type_stats[:namespaces],
          namespace_prefixes: namespace_registry.all_prefixes.size,
          resolved: @resolved,
          validated: @validated,
        }
      end

      # Classify schemas by role and resolution status
      # @return [Hash] Classification results
      def classify_schemas
        require_relative "schema_classifier"
        classifier = SchemaClassifier.new(self)
        classifier.classify
      end

      # Get all registered namespace URIs
      # @return [Array<String>]
      def all_namespaces
        namespace_registry.all_uris
      end

      # Quick type existence check
      # @param qualified_name [String] Qualified name (e.g., "gml:CodeType")
      # @return [Boolean] True if type exists and is resolved
      def type_exists?(qualified_name)
        find_type(qualified_name).resolved?
      end

      # List all type names
      # @param namespace [String, nil] Filter by namespace URI (optional)
      # @param category [Symbol, nil] Filter by category (optional)
      # @return [Array<String>] List of qualified type names
      def all_type_names(namespace: nil, category: nil)
        types = []

        type_index.all.each_value do |type_info|
          # Filter by namespace if specified
          next if namespace && type_info[:namespace] != namespace

          # Filter by category if specified
          next if category && type_info[:type] != category

          # Build qualified name
          ns = type_info[:namespace]
          name = type_info[:definition]&.name
          next unless name

          prefix = namespace_to_prefix(ns)
          qualified_name = prefix ? "#{prefix}:#{name}" : name
          types << qualified_name
        end

        types.sort
      end

      # Export statistics in different formats
      # @param format [Symbol] Output format (:yaml, :json, or :text)
      # @return [String] Formatted statistics
      def export_statistics(format: :yaml)
        stats = statistics

        case format
        when :yaml
          require "yaml"
          stats.to_yaml
        when :json
          require "json"
          JSON.pretty_generate(stats)
        when :text
          format_statistics_as_text(stats)
        else
          raise ArgumentError, "Unsupported format: #{format}"
        end
      end

      # Namespace summary
      # @return [Array<Hash>] Summary of each namespace
      def namespace_summary
        all_namespaces.map do |ns|
          {
            uri: ns,
            prefix: namespace_to_prefix(ns),
            types: types_in_namespace(ns).size,
          }
        end
      end

      # Get the namespace prefix for a URI
      # @param namespace_uri [String, nil] The namespace URI
      # @return [String, nil] The prefix or nil
      def namespace_to_prefix(namespace_uri)
        return nil if namespace_uri.nil? || namespace_uri.empty?

        namespace_registry.get_primary_prefix(namespace_uri)
      end

      # Get detailed namespace prefix information
      # @return [Array<NamespacePrefixInfo>] Detailed prefix information
      def namespace_prefix_details
        manager = NamespacePrefixManager.new(self)
        manager.detailed_prefix_info
      end

      # Remap namespace prefixes
      # @param changes [Hash] Mapping of old_prefix => new_prefix
      # @return [SchemaRepository] New repository with updated prefixes
      def remap_namespace_prefixes(changes)
        remapper = NamespaceRemapper.new(self)
        remapper.remap(changes)
      end

      # Analyze type inheritance hierarchy
      # @param qualified_name [String] The qualified type name (e.g., "gml:AbstractFeatureType")
      # @param depth [Integer] Maximum depth to traverse (default: 10)
      # @return [Hash, nil] Hierarchy analysis result or nil if type not found
      def analyze_type_hierarchy(qualified_name, depth: 10)
        require_relative "type_hierarchy_analyzer"
        analyzer = TypeHierarchyAnalyzer.new(self)
        analyzer.analyze(qualified_name, depth: depth)
      end

      # Analyze coverage based on entry point types
      # @param entry_types [Array<String>] Entry point type names
      # @return [CoverageReport] Coverage analysis results
      def analyze_coverage(entry_types: [])
        require_relative "coverage_analyzer"
        analyzer = CoverageAnalyzer.new(self)
        analyzer.analyze(entry_types: entry_types)
      end

      # Validate XSD specification compliance
      # @param version [String] XSD version to validate against ('1.0' or '1.1')
      # @return [SpecComplianceReport] Validation report
      def validate_xsd_spec(version: "1.0")
        require_relative "xsd_spec_validator"
        validator = XsdSpecValidator.new(self, version: version)
        validator.validate
      end

      # Get all processed schemas including imported/included schemas
      # @return [Hash] All schemas from the global processed_schemas cache
      def all_schemas
        Lutaml::Xml::Schema::Xsd::Schema.processed_schemas
      end

      # The file a schema was parsed from (processed_schemas is keyed by
      # source path); engines compile from the file so relative imports
      # resolve.
      #
      # @param schema [Object] parsed Schema
      # @return [String, nil]
      def source_path_for(schema)
        all_schemas.find { |_path, candidate| candidate.equal?(schema) }
          &.first
      end

      # Get all schemas (alias for compatibility)
      # @return [Hash] All schemas from the global processed_schemas cache
      def schemas
        all_schemas
      end

      # Get all types in a namespace
      # @param namespace_uri [String] The namespace URI
      # @return [Array<Hash>] List of type information
      def types_in_namespace(namespace_uri)
        type_index.find_all_in_namespace(namespace_uri)
      end

      # Get all elements organized by namespace
      # Returns hash: { namespace_uri => [{element_name, type, minOccurs, maxOccurs, documentation}] }
      # @param namespace_uri [String, nil] Filter by specific namespace URI (optional)
      # @return [Hash{String => Array<Hash>}] Elements grouped by namespace
      def elements_by_namespace(namespace_uri: nil)
        results = {}

        all_schemas.each_value do |schema|
          ns = schema.target_namespace
          next if namespace_uri && ns != namespace_uri

          results[ns] ||= []

          (schema.element || []).each do |elem|
            results[ns] << {
              name: elem.name,
              qualified_name: "#{namespace_to_prefix(ns)}:#{elem.name}",
              type: elem.type || "(inline complex type)",
              min_occurs: elem.min_occurs || "1",
              max_occurs: elem.max_occurs || "1",
              documentation: extract_element_documentation(elem),
            }
          end
        end

        results
      end

      # Export repository as a ZIP package with schemas and metadata
      # @param output_path [String] Path to output ZIP file
      # @param xsd_mode [Symbol] :include_all or :allow_external
      # @param resolution_mode [Symbol] :bare or :resolved
      # @param serialization_format [Symbol] :marshal, :json, :yaml, or :parse
      # @param metadata [Hash] Additional metadata to include
      # @return [SchemaRepositoryPackage] Created package
      def to_package(output_path, xsd_mode: :include_all, resolution_mode: :resolved, serialization_format: :marshal,
                     metadata: {})
        # Ensure repository is resolved if creating resolved package
        resolve unless @resolved || resolution_mode == :bare

        # Create package configuration
        config = PackageConfiguration.new(
          xsd_mode: xsd_mode,
          resolution_mode: resolution_mode,
          serialization_format: serialization_format,
        )

        # Delegate to SchemaRepositoryPackage
        SchemaRepositoryPackage.create(
          repository: self,
          output_path: output_path,
          config: config,
          metadata: metadata,
        )
      end

      # Check if repository needs parsing
      # Used by demo scripts to determine if parse() should be called
      # @return [Boolean] True if schemas need to be parsed from XSD files
      def needs_parsing?
        # Check if schemas are already in the global cache
        # (either from package loading or previous parse)
        all_schemas.empty?
      end

      # Add a schema file to the repository
      # @param file_path [String] Path to the schema file
      # @return [void]
      def add_schema_file(file_path)
        @files ||= []
        @files << file_path unless @files.include?(file_path)
      end

      # Add multiple schema files to the repository
      # @param file_paths [Array<String>] Paths to the schema files
      # @return [void]
      def add_schema_files(file_paths)
        file_paths.each { |fp| add_schema_file(fp) }
      end

      # Add a schema location mapping for resolving import/include paths
      # @param mapping [SchemaLocationMapping, Hash] The mapping to add
      # @return [void]
      def add_schema_location_mapping(mapping)
        @schema_location_mappings ||= []
        mapping_obj = if mapping.is_a?(SchemaLocationMapping)
                        mapping
                      elsif mapping.is_a?(Hash)
                        SchemaLocationMapping.from_hash(mapping)
                      else
                        raise ArgumentError,
                              "Expected SchemaLocationMapping or Hash, got #{mapping.class}"
                      end
        @schema_location_mappings << mapping_obj unless @schema_location_mappings.any? do |m|
          m.from == mapping_obj.from
        end
      end

      # Configure schema location mappings for imports/includes
      # @param mappings [Array<Hash>, Array<SchemaLocationMapping>] The mappings to add
      # @return [self]
      def configure_schema_location_mappings(mappings)
        mappings.each { |m| add_schema_location_mapping(m) }
        self
      end

      # Validate a schema repository package
      # @param zip_path [String] Path to ZIP package file
      # @return [SchemaRepositoryPackage::ValidationResult] Validation results
      def self.validate_package(zip_path)
        package = SchemaRepositoryPackage.new(zip_path)
        package.validate
      end

      # Load repository from a ZIP package
      # @param zip_path [String] Path to ZIP package file
      # @return [SchemaRepository] Loaded repository
      def self.from_package(zip_path)
        package = SchemaRepositoryPackage.new(zip_path)
        package.load_repository
      end

      # Load repository configuration from a YAML file
      # @param yaml_path [String] Path to YAML configuration file
      # @return [SchemaRepository] Configured repository
      def self.from_yaml_file(yaml_path)
        yaml_content = File.read(yaml_path)
        base_dir = File.dirname(yaml_path)

        # Use Lutaml::Model's from_yaml to deserialize
        repository = from_yaml(yaml_content)

        # Resolve relative paths in files attribute
        if repository.files
          repository.instance_variable_set(
            :@files,
            repository.files.map do |file|
              if File.absolute_path?(file)
                file
              else
                File.expand_path(file,
                                 base_dir)
              end
            end,
          )
        end

        # Resolve relative paths in base_packages attribute
        if repository.base_packages
          repository.instance_variable_set(
            :@base_packages,
            repository.base_packages.map do |pkg|
              pkg_path = pkg.package
              unless File.absolute_path?(pkg_path)
                expanded_path = File.expand_path(pkg_path, base_dir)
                pkg.package = expanded_path
              end
              pkg
            end,
          )
        end

        # Resolve relative paths in schema_location_mappings
        repository.schema_location_mappings&.each do |mapping|
          unless File.absolute_path?(mapping.to)
            mapping.to = File.expand_path(mapping.to, base_dir)
          end
        end

        repository
      end

      # Auto-detect and load from XSD, LXR, or YAML
      # @param path [String] Path to file (.xsd, .lxr, .yml, or .yaml)
      # @return [SchemaRepository] Loaded repository
      def self.from_file(path)
        # Check file exists first
        unless File.exist?(path)
          raise Errno::ENOENT,
                "No such file or directory - #{path}"
        end

        case File.extname(path).downcase
        when ".lxr"
          repo = from_package(path)
          # Ensure loaded repository is resolved
          repo.resolve unless repo.instance_variable_get(:@resolved)
          repo
        when ".xsd", ".rng", ".rnc"
          repo = new
          repo.instance_variable_set(:@files, [File.expand_path(path)])
          repo.parse.resolve
          repo
        when ".yml", ".yaml"
          repo = from_yaml_file(path)
          # Parse and resolve if needed
          repo.parse.resolve	if repo.needs_parsing?
          repo
        else
          raise ConfigurationError,
                "Unsupported file type: #{path}. Expected .xsd, .rng, .rnc, .lxr, .yml, or .yaml"
        end
      end

      # Smart caching: only rebuild when source is newer than cache
      # @param source_path [String] Path to source file (.xsd or .yml/.yaml)
      # @param lxr_path [String, nil] Optional path to cache file (default: source with .lxr extension)
      # @return [SchemaRepository] Loaded repository
      def self.from_file_cached(source_path, lxr_path: nil)
        lxr_path ||= source_path.sub(/\.(xsd|ya?ml)$/, ".lxr")

        # Check if cache exists and is fresh
        if File.exist?(lxr_path) &&
            File.mtime(lxr_path) >= File.mtime(source_path)
          # Use from_file to ensure proper resolution
          from_file(lxr_path)
        else
          # Cache missing or stale, rebuild
          repo = from_file(source_path)

          # Create cache package
          repo.to_package(
            lxr_path,
            xsd_mode: :include_all,
            resolution_mode: :resolved,
            serialization_format: :marshal,
          )

          repo
        end
      end

      # Normalize base_packages to BasePackageConfig objects
      # Handles both legacy string format and new hash/config format
      # @return [Array<BasePackageConfig>]
      def normalize_base_packages_to_configs
        (base_packages || []).map do |pkg|
          case pkg
          when String
            BasePackageConfig.new(package: pkg)
          when Hash
            # Convert string keys to symbols for BasePackageConfig
            symbolized = pkg.transform_keys do |k|
              k.is_a?(String) ? k.to_sym : k
            end
            BasePackageConfig.new(**symbolized)
          when BasePackageConfig
            pkg
          else
            # Fallback for any other type
            BasePackageConfig.new(package: pkg.to_s)
          end
        end
      end

      # Load packages with conflict detection and resolution
      # @param glob_mappings [Array<Hash>] Schema location mappings
      # @raise [PackageMergeError] If conflicts with error strategy
      def load_base_packages_with_conflict_detection(glob_mappings)
        configs = normalize_base_packages_to_configs

        # Validate all configs
        configs.each do |config|
          result = config.validate
          raise ValidationFailedError, result if result.invalid?
        end

        if @verbose
          puts "Detecting conflicts in #{configs.size} package(s)..."
        end

        # Detect conflicts
        detector = PackageConflictDetector.new(configs)
        report = detector.detect_conflicts

        if @verbose && report.has_conflicts?
          puts "⚠️  #{report.total_conflicts} conflict(s) detected"
        elsif @verbose
          puts "✓ No conflicts detected"
        end

        # Resolve conflicts (may raise PackageMergeError)
        resolver = PackageConflictResolver.new(report, report.package_sources)
        ordered_sources = resolver.resolve

        if @verbose
          puts "Loading #{ordered_sources.size} package(s) in priority order..."
        end

        # Load packages in resolved order
        ordered_sources.each_with_index do |source, idx|
          if @verbose
            print "\r[#{idx + 1}/#{ordered_sources.size}] #{File.basename(source.package_path)}"
            $stdout.flush
          end

          load_package_with_filtering(source, glob_mappings)
        end

        puts "\n✓ All packages merged successfully" if @verbose
      end

      # Load a single package with schema filtering
      # @param package_source [PackageSource] The package to load
      # @param glob_mappings [Array<Hash>] Schema location mappings
      def load_package_with_filtering(package_source, _glob_mappings)
        repo = package_source.repository

        # Get all schemas from the package
        store = repo.parsed_schemas
        all_schemas = store ? store.all : {}

        # Apply schema filtering from config
        filtered_schemas = all_schemas.select do |path, _schema|
          package_source.include_schema?(path)
        end

        # Apply namespace remapping if configured
        if package_source.namespace_remapping.any?
          filtered_schemas = apply_namespace_remapping_to_schemas(
            filtered_schemas,
            package_source.namespace_remapping,
          )
        end

        # Merge filtered schemas into current repository
        parsed_schemas.bulk_set(filtered_schemas)

        # Merge files list
        @files ||= []
        filtered_files = (repo.files || []).select do |file|
          package_source.include_schema?(file)
        end
        @files.concat(filtered_files)

        # Merge namespace mappings
        repo.namespace_mappings&.each do |mapping|
          configure_namespace(prefix: mapping.prefix, uri: mapping.uri)
        end

        # Merge schema location mappings
        repo.schema_location_mappings&.each do |mapping|
          @schema_location_mappings ||= []
          unless @schema_location_mappings.any? { |m| m.from == mapping.from }
            @schema_location_mappings << mapping
          end
        end
      end

      # Check if base_packages contains configuration objects
      # @return [Boolean]
      def supports_conflict_detection?
        return false unless base_packages&.any?

        # If any element is a Hash or BasePackageConfig, use conflict detection
        base_packages.any? do |pkg|
          pkg.is_a?(Hash) || pkg.is_a?(BasePackageConfig) ||
            (pkg.is_a?(String) && pkg.start_with?("{"))
        end
      end

      # Apply namespace remapping to schemas
      # @param schemas [Hash] Schema hash to transform
      # @param remappings [Array<NamespaceUriRemapping>] Remapping rules
      # @return [Hash] Transformed schemas
      def apply_namespace_remapping_to_schemas(schemas, remappings)
        uri_mappings = {}
        remappings.each { |remap| uri_mappings[remap.from_uri] = remap.to_uri }

        # This is a simplified version - in practice, you'd need to
        # deeply transform all namespace references in the schema objects
        # For now, just return the schemas as-is since remapping is
        # handled during conflict detection
        schemas
      end

      private

      # Load schemas from base LXR packages (legacy method)
      # @param glob_mappings [Array<Hash>] Schema location mappings
      def load_base_packages(glob_mappings)
        puts "Loading #{base_packages.size} base package(s)..." if @verbose

        base_packages.each_with_index do |lxr_path, idx|
          # Resolve relative paths
          resolved_path = if File.absolute_path?(lxr_path)
                            lxr_path
                          else
                            File.expand_path(lxr_path, Dir.pwd)
                          end

          unless File.exist?(resolved_path)
            warn "Warning: Base package not found: #{resolved_path}"
            next
          end

          if @verbose
            print "\r[#{idx + 1}/#{base_packages.size}] Loading #{File.basename(resolved_path)}"
            $stdout.flush
          end

          load_package_schemas(resolved_path, glob_mappings)
        end

        puts "\n✓ All base packages loaded" if @verbose
      end

      # Load schemas from a single LXR package
      # @param lxr_path [String] Path to LXR package
      # @param glob_mappings [Array<Hash>] Schema location mappings
      def load_package_schemas(lxr_path, glob_mappings)
        # Load the package repository
        package_repo = SchemaRepository.from_package(lxr_path)

        # Add all schema files from package to this repository
        package_repo.files&.each do |file_path|
          add_schema_file(file_path)
          # Parse immediately if file exists
          parse_schema_file(file_path, glob_mappings) if File.exist?(file_path)
        end

        # Merge namespace mappings from package
        package_repo.namespace_mappings&.each do |mapping|
          configure_namespace(prefix: mapping.prefix, uri: mapping.uri)
        end

        # Merge schema location mappings from package
        package_repo.schema_location_mappings&.each do |mapping|
          @schema_location_mappings ||= []
          @schema_location_mappings << mapping unless @schema_location_mappings.any? do |m|
            m.from == mapping.from
          end
        end
      end

      # Parse a single schema file
      # @param file_path [String] Path to schema file
      # @param glob_mappings [Array<Hash>] Schema location mappings
      def parse_schema_file(file_path, glob_mappings)
        return if parsed_schemas.exists?(file_path)
        return unless File.exist?(file_path)

        ext = File.extname(file_path).downcase
        parsed_schema = if %w[.rng .rnc].include?(ext)
                          parse_rng_schema(file_path)
                        else
                          parse_xsd_schema(file_path, glob_mappings)
                        end

        parsed_schemas.set(file_path, parsed_schema)

        # Register in global cache for cross-repository access
        Lutaml::Xml::Schema::Xsd::Schema.schema_processed(file_path,
                                                          parsed_schema)
      rescue StandardError => e
        warn "Warning: Failed to parse schema #{file_path}: #{e.message}"
        # Parse errors are expected for schemas with unresolvable imports
        # The schema still gets added to Schema.processed_schemas by Lutaml::Xml::Schema::Xsd.parse
        # even if import resolution fails, so local types may still be indexed
      end

      # Parse an XSD schema file
      # @param file_path [String] Path to XSD file
      # @param glob_mappings [Array<Hash>] Schema location mappings
      # @return [Lutaml::Xml::Schema::Xsd::Schema]
      def parse_xsd_schema(file_path, glob_mappings)
        xsd_content = File.read(file_path)
        Lutaml::Xml::Schema::Xsd.parse(
          xsd_content,
          location: File.dirname(file_path),
          schema_mappings: glob_mappings,
        )
      end

      # Parse an RNG or RNC schema file and convert to XSD.
      # Generates a temporary .xsd file from the converted schema so that
      # the bundler can package it in the expected XSD format.
      # @param file_path [String] Path to .rng or .rnc file
      # @return [Lutaml::Xml::Schema::Xsd::Schema]
      def parse_rng_schema(file_path)
        require "rng"

        grammar = if file_path.downcase.end_with?(".rnc")
                    Rng.parse_file(file_path)
                  else
                    rng_content = File.read(file_path)
                    Rng.parse(rng_content,
                              location: File.dirname(file_path),
                              resolve_external: true)
                  end

        schema = RngToXsdConverter.new(grammar, file_path: file_path).convert

        # Generate a temporary .xsd file from the converted schema
        xsd_content = schema.to_formatted_xml
        xsd_path = file_path.sub(/\.(rng|rnc)$/i, ".xsd")

        # Write to a temp file if the .xsd path would overwrite an existing file,
        # or if we can't write to the original directory
        begin
          File.write(xsd_path, xsd_content)
        rescue StandardError
          # Fall back to a temp directory
          require "tmpdir"
          xsd_path = File.join(Dir.tmpdir, "lutaml_xsd_#{File.basename(file_path, '.*')}.xsd")
          File.write(xsd_path, xsd_content)
        end

        # Update file references to point to the generated .xsd
        update_rng_file_references(file_path, xsd_path)

        schema
      end

      # Update internal references from an RNG/RNC path to the generated XSD path
      # @param old_path [String] Original .rng/.rnc file path
      # @param new_path [String] Generated .xsd file path
      def update_rng_file_references(old_path, new_path)
        # Update @files array
        if @files
          idx = @files.index(old_path)
          @files[idx] = new_path if idx
        end

        # Update parsed_schemas store
        if parsed_schemas.exists?(old_path)
          parsed_schemas.set(new_path, parsed_schemas.get(old_path))
          parsed_schemas.delete(old_path)
        end

        # Update global cache
        cached = Lutaml::Xml::Schema::Xsd::Schema.processed_schemas
        if cached.key?(old_path)
          cached[new_path] = cached.delete(old_path)
        end
      end

      # Check for circular imports (simplified check)
      # @param errors [Array<String>] Array to collect errors
      # @param strict [Boolean] Whether to raise on first error
      def check_circular_imports(errors, strict)
        # Track schema dependencies
        dependencies = {}

        parsed_schemas.all.each do |file_path, schema|
          deps = (schema.imports || []).map(&:schema_path)
          (schema.includes || []).each do |include|
            deps << include.schema_path
          end
          dependencies[file_path] = deps.compact
        end

        # Simple circular dependency check using DFS
        visited = {}
        dependencies.each_key do |file|
          next unless has_circular_dependency?(file, dependencies, visited, [])

          error = "Circular import detected involving: #{file}"
          errors << error
          raise Error, error if strict
        end
      end

      # Check for circular dependency using depth-first search
      # @param file [String] Current file to check
      # @param dependencies [Hash] Dependency graph
      # @param visited [Hash] Visited nodes tracking
      # @param path [Array<String>] Current path being explored
      # @return [Boolean] True if circular dependency found
      def has_circular_dependency?(file, dependencies, visited, path)
        return false if visited[file] == :permanent

        if path.include?(file)
          return true # Circular dependency found
        end

        visited[file] = :temporary
        path.push(file)

        (dependencies[file] || []).each do |dep|
          return true if has_circular_dependency?(dep, dependencies, visited,
                                                  path)
        end

        path.pop
        visited[file] = :permanent
        false
      end

      # Format statistics as human-readable text
      # @param stats [Hash] Statistics hash
      # @return [String] Formatted text
      def format_statistics_as_text(stats)
        lines = []
        lines << "Schema Repository Statistics"
        lines << ("=" * 40)
        lines << "Total Schemas: #{stats[:total_schemas]}"
        lines << "Total Types: #{stats[:total_types]}"
        lines << "Total Namespaces: #{stats[:total_namespaces]}"
        lines << "Namespace Prefixes: #{stats[:namespace_prefixes]}"
        lines << ""
        lines << "Types by Category:"
        stats[:types_by_category].each do |type, count|
          lines << "  #{type}: #{count}"
        end
        lines << ""
        lines << "Resolved: #{stats[:resolved]}"
        lines << "Validated: #{stats[:validated]}"
        lines.join("\n")
      end

      # Count total number of imports across all schemas
      # @param schemas [Hash] Hash of schemas
      # @return [Integer] Total import count
      def count_total_imports(schemas)
        schemas.values.sum do |schema|
          imports = schema.import
          (imports || []).size
        end
      end

      # Extract documentation from an element's annotation
      # @param elem [Element] The element to extract documentation from
      # @return [String] The documentation text or empty string
      def extract_element_documentation(elem)
        return "" unless elem.annotation&.documentation

        docs = elem.annotation.documentation
        docs = [docs] unless docs.is_a?(Array)

        docs.filter_map do |doc|
          content = doc.content || doc.to_s
          content&.strip
        end.first || ""
      end
    end
  end
end

require_relative "schema_repository/namespace_registry"
require_relative "schema_repository/type_index"
require_relative "schema_repository/qualified_name_parser"
require_relative "namespace_prefix_manager"
require_relative "namespace_remapper"
