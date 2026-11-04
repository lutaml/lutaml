# frozen_string_literal: true

module Expressir
  module Model
    # Resolves dependencies between EXPRESS schemas
    # Handles USE FROM and REFERENCE FROM interfaces
    # Detects circular dependencies
    class DependencyResolver
      # Exception for circular dependencies
      class CircularDependencyError < StandardError
        attr_reader :dependency_chain

        def initialize(message, chain)
          super(message)
          @dependency_chain = chain
        end
      end

      attr_reader :base_dirs, :schema_registry, :verbose, :unresolved

      # Initialize resolver
      # @param base_dirs [String, Array<String>] Base directories to search
      # @param schema_registry [Hash] Manual schema name => path mappings
      # @param verbose [Boolean] Enable verbose logging
      def initialize(base_dirs: Dir.pwd, schema_registry: {}, verbose: false)
        @base_dirs = Array(base_dirs).map { |d| File.expand_path(d) }
        @schema_registry = schema_registry || {}
        @verbose = verbose
        @resolved_schemas = Set.new
        @resolution_stack = []
        @unresolved = []
        @last_found_base_index = nil
        @last_found_base_dir = nil
        @multiple_matches = []
      end

      # Resolve all dependencies starting from root schema
      # @param root_schema_path [String] Path to root schema file
      # @return [Array<String>] Ordered list of schema file paths
      def resolve_dependencies(root_schema_path)
        @resolved_schemas.clear
        @resolution_stack.clear
        @unresolved.clear

        resolve_recursive(File.expand_path(root_schema_path))
        @resolved_schemas.to_a
      end

      # Extract interfaces from schema file using proper parsing
      # @param schema_path [String] Path to schema file
      # @return [Array<Hash>] List of interfaces with :kind, :schema_name
      def extract_interfaces(schema_path)
        interfaces = []

        # Parse the schema file properly
        repo = Expressir::Express::Parser.from_file(schema_path)

        # Extract interfaces from first schema (file should contain one schema)
        schema = repo.schemas.first
        return interfaces unless schema&.interfaces

        schema.interfaces.each do |interface|
          kind = case interface.kind
                 when Expressir::Model::Declarations::Interface::USE
                   "USE"
                 when Expressir::Model::Declarations::Interface::REFERENCE
                   "REFERENCE"
                 else
                   interface.kind.first
                 end

          interfaces << {
            kind: kind,
            schema_name: interface.schema.id,
          }
        end

        interfaces
      end

      # Resolve schema location
      # @param schema_name [String] Schema name to find
      # @param kind [String] Interface kind ("USE" or "REFERENCE")
      # @param current_path [String] Path of schema requesting the reference
      # @return [String, nil] Path to schema file, or nil if not found
      def resolve_schema_location(schema_name, _kind, _current_path)
        # Check schema_registry first
        if @schema_registry[schema_name]
          registry_path = File.expand_path(@schema_registry[schema_name])
          return registry_path if File.exist?(registry_path)
        end

        # Search ONLY in base_dirs recursively and collect ALL matches
        all_matches = []
        @base_dirs.each_with_index do |base_dir, index|
          candidate = find_schema_in_directory(schema_name, base_dir)
          if candidate
            all_matches << { path: candidate, base_dir: base_dir, index: index }
          end
        end

        # If no matches found, return nil
        return nil if all_matches.empty?

        # If multiple matches found, record for warning
        if all_matches.size > 1
          @multiple_matches << {
            schema_name: schema_name,
            matches: all_matches,
          }
        end

        # Use the first match
        first_match = all_matches.first
        @last_found_base_index = first_match[:index]
        @last_found_base_dir = first_match[:base_dir]

        first_match[:path]
      end

      # Get resolution statistics
      # @return [Hash] Statistics about resolved schemas
      def statistics
        {
          total_schemas: @resolved_schemas.size,
          schemas: @resolved_schemas.to_a,
          base_dirs: @base_dirs,
          multiple_matches: @multiple_matches,
        }
      end

      private

      # Resolve schema and its dependencies recursively
      # @param schema_path [String] Path to schema file
      # @return [void]
      def resolve_recursive(schema_path)
        return if @resolved_schemas.include?(schema_path)

        # Check for circular dependency - schema-level circular references are valid in EXPRESS
        if @resolution_stack.include?(schema_path)
          # Schema is already being processed - this is a back-reference
          # Skip re-processing; the schema will be added to resolved_schemas when its original pass completes
          return
        end

        @resolution_stack.push(schema_path)

        # Extract and resolve interfaces
        interfaces = extract_interfaces(schema_path)
        interfaces.each do |interface|
          if @verbose
            schema_name = File.basename(schema_path, ".*")
            print "  #{interface[:kind]} FROM #{interface[:schema_name]} (in #{schema_name}): "
          end

          dep_path = resolve_schema_location(
            interface[:schema_name],
            interface[:kind],
            schema_path,
          )

          if dep_path
            if @verbose
              # Show which source and relative path
              if @last_found_base_dir && @last_found_base_index
                relative_path = dep_path.sub("#{@last_found_base_dir}/", "")
                source_label = "[source #{@last_found_base_index + 1}]"
                puts "\e[32m✓\e[0m #{source_label} #{relative_path}"
              else
                relative_path = File.basename(dep_path)
                puts "\e[32m✓\e[0m #{relative_path}"
              end
            end
            resolve_recursive(dep_path)
          else
            # Track unresolved reference
            @unresolved << {
              from: schema_path,
              kind: interface[:kind],
              schema_name: interface[:schema_name],
            }

            if @verbose
              puts "\e[31m✗ not found\e[0m"
            end
          end
        end

        @resolution_stack.pop
        @resolved_schemas.add(schema_path)
      end

      # Find schema file in directory
      # @param schema_name [String] Schema name to find
      # @param directory [String] Directory to search
      # @param recursive [Boolean] Whether to search subdirectories
      # @return [String, nil] Path to schema file or nil
      def find_schema_in_directory(schema_name, directory)
        return nil unless File.directory?(directory)

        # Try direct match first (resource pattern: schema_name.exp)
        candidate = File.join(directory, "#{schema_name}.exp")
        return File.expand_path(candidate) if File.exist?(candidate)

        # Try module pattern: {lower-case-prefix-without-_schema}/{arm|mim}.exp
        # Examples:
        #   Activity_method_mim -> activity_method/mim.exp
        #   Activity_method_arm -> activity_method/arm.exp
        module_path = try_module_pattern(schema_name, directory)
        return module_path if module_path

        # Search recursively in subdirectories
        # Only in base_dirs to avoid permission errors in system directories
        begin
          # First try direct name match
          Dir.glob(File.join(directory, "**",
                             "#{schema_name}.exp")).each do |file|
            return File.expand_path(file)
          end

          # Also try module pattern recursively for _arm/_mim schemas
          if schema_name =~ /^(.+)_(arm|mim)$/i
            prefix = Regexp.last_match(1)
            suffix = Regexp.last_match(2).downcase
            prefix = prefix.sub(/_schema$/i, "")
            module_dir = prefix.downcase

            # Search for **/module_dir/suffix.exp pattern
            Dir.glob(File.join(directory, "**", module_dir,
                               "#{suffix}.exp")).each do |file|
              return File.expand_path(file)
            end
          end
        rescue Errno::EACCES, Errno::EPERM
          # Ignore permission errors when searching directories
          nil
        end

        nil
      end

      # Try module naming pattern
      # @param schema_name [String] Schema name (e.g., "Activity_method_mim")
      # @param directory [String] Base directory
      # @return [String, nil] Path if found, nil otherwise
      def try_module_pattern(schema_name, directory)
        # Check if schema name ends with _arm or _mim
        if schema_name =~ /^(.+)_(arm|mim)$/i
          prefix = Regexp.last_match(1)
          suffix = Regexp.last_match(2).downcase

          # Remove trailing _schema if present
          prefix = prefix.sub(/_schema$/i, "")

          # Convert to lowercase and replace underscores
          module_dir = prefix.downcase

          # Try: directory/module_dir/suffix.exp
          candidate = File.join(directory, module_dir, "#{suffix}.exp")
          return File.expand_path(candidate) if File.exist?(candidate)
        end

        nil
      end
    end
  end
end
