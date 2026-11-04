# frozen_string_literal: true

require "thor"
require_relative "base_command"
require_relative "package_command"
require_relative "tree_command"
require_relative "stats_command"
require_relative "coverage_command"
require_relative "verify_command"
require_relative "metadata_command"
require_relative "type_command"
require_relative "search_command"
require_relative "namespace_command"
require_relative "element_command"
require_relative "../entrypoint_identifier"
require_relative "../schema_dependency_analyzer"
require_relative "../definition_extractor"

module Lutaml
  module Xsd
    module Commands
      # Package inspection commands (MECE category)
      # Handles all package querying, listing, and inspection operations
      class PkgCommand < Thor
        class_option :verbose,
                     type: :boolean,
                     default: false,
                     desc: "Enable verbose output"

        desc "ls PACKAGE", "List all schemas in package"
        long_desc <<~DESC
          Display all XSD schema files contained in a schema repository package.

          Shows information about each schema including filename, target namespace,
          number of elements, and number of types defined.

          Examples:
            # List schemas in text format
            lutaml-xsd pkg ls pkg/my_schemas.lxr

            # List schemas in JSON format
            lutaml-xsd pkg ls pkg/my_schemas.lxr --format json

            # Classify schemas by role and status
            lutaml-xsd pkg ls pkg/my_schemas.lxr --classify
        DESC
        option :format,
               type: :string,
               default: "text",
               enum: %w[text json yaml],
               desc: "Output format (text, json, yaml)"
        option :classify,
               type: :boolean,
               default: false,
               desc: "Classify schemas by role and resolution status"
        def ls(package_path)
          require_relative "package_command"
          PackageCommand::SchemasCommand.new(package_path, options).run
        end

        desc "tree PACKAGE", "Show package file tree"
        long_desc <<~DESC
          Display all contents of an LXR package file in a colorized tree structure.

          Shows organized view of package contents including:
          - Metadata files
          - XSD schema files
          - Serialized schema data
          - Type indexes

          Examples:
            # Basic tree view
            lutaml-xsd pkg tree pkg/urban_function.lxr

            # With file sizes
            lutaml-xsd pkg tree pkg/urban_function.lxr --show-sizes

            # Without colors (for CI/logging)
            lutaml-xsd pkg tree pkg/urban_function.lxr --no-color
        DESC
        option :show_sizes,
               type: :boolean,
               default: false,
               desc: "Show file sizes"
        option :no_color,
               type: :boolean,
               default: false,
               desc: "Disable colored output"
        option :format,
               type: :string,
               default: "tree",
               enum: %w[tree flat],
               desc: "Output format (tree or flat)"
        def tree(package_path)
          require_relative "tree_command"
          TreeCommand.new(package_path, options).run
        end

        desc "inspect PACKAGE", "Show full package details"
        long_desc <<~DESC
          Display comprehensive package metadata and statistics.

          Examples:
            # Show package info
            lutaml-xsd pkg inspect pkg/my_schemas.lxr

            # Output as JSON
            lutaml-xsd pkg inspect pkg/my_schemas.lxr --format json
        DESC
        option :format,
               type: :string,
               default: "text",
               enum: %w[text json yaml],
               desc: "Output format"
        def inspect(package_path)
          require_relative "package_command"
          PackageCommand::InfoCommand.new(package_path, options).run
        end

        desc "stats PACKAGE", "Display package statistics"
        long_desc <<~DESC
          Display comprehensive statistics for a schema repository package.

          The statistics include:
          - Total number of schemas parsed
          - Total number of types indexed
          - Types breakdown by category (complex, simple, element, attribute, etc.)
          - Total number of namespaces

          Examples:
            # Display statistics
            lutaml-xsd pkg stats pkg/my_schemas.lxr

            # Display statistics in JSON format
            lutaml-xsd pkg stats pkg/my_schemas.lxr --format json
        DESC
        option :format,
               type: :string,
               enum: %w[text json yaml],
               default: "text",
               desc: "Output format (text, json, yaml)"
        def stats(package_path)
          require_relative "stats_command"
          StatsCommand::ShowCommand.new(package_path, options).run
        end

        desc "extract PACKAGE SCHEMA", "Extract a schema from the package"
        long_desc <<~DESC
          Extract a specific XSD schema file from a schema repository package.

          The SCHEMA_NAME can be either a full filename (e.g., "schema.xsd") or just
          the basename without extension (e.g., "schema").

          Examples:
            # Extract a schema to stdout
            lutaml-xsd pkg extract pkg/my_schemas.lxr unitsml-v1.0-csd04.xsd

            # Extract a schema to a file
            lutaml-xsd pkg extract pkg/my_schemas.lxr unitsml-v1.0-csd04.xsd -o /tmp/extracted.xsd

            # Extract using basename only
            lutaml-xsd pkg extract pkg/my_schemas.lxr unitsml-v1.0-csd04 -o /tmp/extracted.xsd
        DESC
        option :output,
               type: :string,
               aliases: "-o",
               desc: "Output file path (default: stdout)"
        def extract(package_path, schema_name)
          require_relative "package_command"
          PackageCommand::ExtractCommand.new(package_path, schema_name,
                                             options).run
        end

        desc "coverage PACKAGE", "Analyze schema coverage from entry points"
        long_desc <<~DESC
          Analyze which types are reachable from entry point types.
          Shows used vs unused types and coverage percentage.

          Examples:
            # Analyze coverage from Building and Road types
            lutaml-xsd pkg coverage schemas.lxr --entry "Building,Road,Bridge"

            # Output in JSON format
            lutaml-xsd pkg coverage schemas.lxr --entry "unitsml:UnitType" --format json
        DESC
        option :entry,
               type: :string,
               required: true,
               desc: "Comma-separated entry types (e.g., 'Type1,ns:Type2')"
        option :format,
               type: :string,
               default: "text",
               enum: %w[text json yaml],
               desc: "Output format"
        def coverage(package_path)
          require_relative "coverage_command"
          CoverageCommand.new(package_path, options).run
        end

        desc "verify PACKAGE", "Verify XSD specification compliance"
        long_desc <<~DESC
          Validate schemas against W3C XSD specification.

          Checks for:
          - Target namespace requirements
          - Element/attribute form defaults
          - Circular imports
          - Duplicate definitions
          - Schema location completeness
          - Namespace consistency

          Examples:
            lutaml-xsd pkg verify schemas.lxr
            lutaml-xsd pkg verify schemas.lxr --xsd-version 1.1
            lutaml-xsd pkg verify schemas.lxr --strict
            lutaml-xsd pkg verify schemas.lxr --format json
        DESC
        option :xsd_version,
               type: :string,
               default: "1.0",
               enum: %w[1.0 1.1],
               desc: "XSD version to validate against"
        option :strict,
               type: :boolean,
               desc: "Fail on warnings"
        option :format,
               type: :string,
               default: "text",
               enum: %w[text json yaml],
               desc: "Output format"
        def verify(package_path)
          require_relative "verify_command"
          VerifyCommand.new(package_path, options).run
        end

        desc "metadata SUBCOMMAND", "Manage package metadata"
        long_desc <<~DESC
          Manage package metadata.

          Examples:
            lutaml-xsd pkg metadata show schemas.lxr
            lutaml-xsd pkg metadata update schemas.lxr --name "My Schemas"
        DESC
        subcommand "metadata", Commands::MetadataCommand

        desc "type SUBCOMMAND", "Query and explore schema types"
        long_desc <<~DESC
          Query and explore schema types within packages.

          Commands:
            find         - Find type(s) - supports batch mode
            list         - List all types in the repository
            dependencies - Show what a type depends on
            dependents   - Show what depends on a type
            hierarchy    - Show type inheritance hierarchy

          Examples:
            lutaml-xsd pkg type find "gml:CodeType" schemas.lxr
            lutaml-xsd pkg type list schemas.lxr
            lutaml-xsd pkg type dependencies "unitsml:UnitType" schemas.lxr
            lutaml-xsd pkg type hierarchy "gml:AbstractFeatureType" schemas.lxr
        DESC
        subcommand "type", Commands::TypeCommand

        desc "search QUERY PACKAGE", "Search for types by name or documentation"
        long_desc <<~DESC
          Search for types in a schema repository package by name, documentation, or both.

          Examples:
            # Search for types containing "unit" in name or documentation
            lutaml-xsd pkg search "unit" unitsml-auto.lxr

            # Search only in type names
            lutaml-xsd pkg search "system" unitsml-auto.lxr --in name

            # Search only in documentation
            lutaml-xsd pkg search "container" unitsml-auto.lxr --in documentation

            # Filter by namespace
            lutaml-xsd pkg search "unit" unitsml-auto.lxr --namespace http://www.unitsml.org/unitsml/1.0

            # Filter by category
            lutaml-xsd pkg search "type" unitsml-auto.lxr --category complex_type

            # Output as JSON
            lutaml-xsd pkg search "unit" unitsml-auto.lxr --format json
        DESC
        option :in,
               type: :string,
               default: "both",
               enum: %w[name documentation both],
               desc: "Search in: name, documentation, or both"
        option :namespace,
               type: :string,
               desc: "Filter by namespace URI"
        option :category,
               type: :string,
               enum: %w[element complex_type simple_type attribute_group group],
               desc: "Filter by type category"
        option :limit,
               type: :numeric,
               default: 20,
               desc: "Maximum number of results"
        option :format,
               type: :string,
               default: "text",
               enum: %w[text json yaml],
               desc: "Output format"
        def search(query, package_path)
          require_relative "search_command"
          Commands::SearchCommand.new(query, package_path, options).run
        end

        desc "namespace SUBCOMMAND", "Explore namespaces"
        long_desc <<~DESC
          Explore namespaces in schema packages.

          Examples:
            lutaml-xsd pkg namespace list schemas.lxr
            lutaml-xsd pkg namespace show http://www.example.com schemas.lxr
        DESC
        subcommand "namespace", Commands::NamespaceCommand

        desc "element SUBCOMMAND", "Explore elements"
        long_desc <<~DESC
          Explore elements in schema packages.

          Examples:
            lutaml-xsd pkg element list schemas.lxr
            lutaml-xsd pkg element find "BuildingType" schemas.lxr
        DESC
        subcommand "element", Commands::ElementCommand

        desc "entrypoints PACKAGE", "Show package entrypoints and dependencies"
        long_desc <<~DESC
          Display entrypoint schemas and their dependencies.

          Use --tree to show full dependency hierarchy from entrypoints.

          Examples:
            # List entrypoints and dependencies
            lutaml-xsd pkg entrypoints urban_function.lxr

            # Show dependency tree
            lutaml-xsd pkg entrypoints --tree urban_function.lxr

            # Limit tree depth
            lutaml-xsd pkg entrypoints --tree --depth 3 urban_function.lxr
        DESC
        option :tree,
               type: :boolean,
               default: false,
               desc: "Show dependency tree from entrypoints"
        option :depth,
               type: :numeric,
               desc: "Maximum depth for tree display"
        def entrypoints(package_path)
          package = SchemaRepositoryPackage.new(package_path)
          identifier = EntrypointIdentifier.new(package)

          entrypoints = identifier.identify_entrypoints
          dependencies = identifier.get_dependencies

          if options[:tree]
            display_entrypoint_tree(package, entrypoints, options[:depth])
          else
            display_entrypoints_list(entrypoints, dependencies)
          end
        end

        desc "type-def QNAME PACKAGE", "Show XSD definition for a type"
        long_desc <<~DESC
          Extract and display the complete XSD definition for a type.

          Shows namespace, file location, line number, and full XSD source code.
          Also displays inheritance hierarchy and usage information.

          Examples:
            lutaml-xsd pkg type-def "gml:PointType" gml.lxr
            lutaml-xsd pkg type-def "UrbanFacilityType" urban_function.lxr
        DESC
        def type_def(qname, package_path)
          package = SchemaRepositoryPackage.new(package_path)
          extractor = DefinitionExtractor.new(package)

          definition = extractor.extract_type_definition(qname)

          if definition
            display_type_definition(definition)
          else
            puts "Type '#{qname}' not found in package"
            raise CommandError
          end
        end

        desc "element-def QNAME PACKAGE", "Show XSD definition for an element"
        long_desc <<~DESC
          Extract and display the complete XSD definition for an element.

          Shows namespace, file location, line number, type, substitution group,
          and full XSD source code.

          Examples:
            lutaml-xsd pkg element-def "gml:Point" gml.lxr
            lutaml-xsd pkg element-def "UrbanFacility" urban_function.lxr
        DESC
        def element_def(qname, package_path)
          package = SchemaRepositoryPackage.new(package_path)
          extractor = DefinitionExtractor.new(package)

          definition = extractor.extract_element_definition(qname)

          if definition
            display_element_definition(definition)
          else
            puts "Element '#{qname}' not found in package"
            raise CommandError
          end
        end

        desc "attribute-def QNAME PACKAGE",
             "Show XSD definition for an attribute"
        long_desc <<~DESC
          Extract and display the complete XSD definition for an attribute.

          Shows namespace, file location, line number, type, use, and default/fixed values.

          Examples:
            lutaml-xsd pkg attribute-def "status" urban_function.lxr
            lutaml-xsd pkg attribute-def "@id" gml.lxr
        DESC
        def attribute_def(qname, package_path)
          package = SchemaRepositoryPackage.new(package_path)
          extractor = DefinitionExtractor.new(package)

          definition = extractor.extract_attribute_definition(qname)

          if definition
            display_attribute_definition(definition)
          else
            puts "Attribute '#{qname}' not found in package"
            raise CommandError
          end
        end

        desc "namespace-types URI PACKAGE", "Show all types in namespace"
        long_desc <<~DESC
          Filter and display all types in a specific namespace.

          The URI can be a full namespace URI or a prefix.

          Examples:
            lutaml-xsd pkg namespace-types "urf" urban_function.lxr
            lutaml-xsd pkg namespace-types "http://www.opengis.net/gml/3.2" gml.lxr
        DESC
        option :format,
               type: :string,
               default: "text",
               enum: %w[text json yaml],
               desc: "Output format"
        def namespace_types(uri, package_path)
          package = SchemaRepositoryPackage.new(package_path)
          repository = package.load_repository

          namespace_uri = resolve_namespace_uri(repository, uri)

          types = filter_types_by_namespace(repository, namespace_uri)

          display_namespace_types(namespace_uri, types, options[:format])
        end

        desc "namespace-elements URI PACKAGE", "Show all elements in namespace"
        long_desc <<~DESC
          Filter and display all elements in a specific namespace.

          The URI can be a full namespace URI or a prefix.

          Examples:
            lutaml-xsd pkg namespace-elements "urf" urban_function.lxr
            lutaml-xsd pkg namespace-elements "http://www.opengis.net/gml/3.2" gml.lxr
        DESC
        option :format,
               type: :string,
               default: "text",
               enum: %w[text json yaml],
               desc: "Output format"
        def namespace_elements(uri, package_path)
          package = SchemaRepositoryPackage.new(package_path)
          repository = package.load_repository

          namespace_uri = resolve_namespace_uri(repository, uri)

          elements = filter_elements_by_namespace(repository, namespace_uri)

          display_namespace_elements(namespace_uri, elements, options[:format])
        end

        # Command aliases
        map "cov" => :coverage
        map "s" => :search
        map "?" => :search

        private

        # Display entrypoints list
        def display_entrypoints_list(entrypoints, dependencies)
          puts
          puts "ENTRYPOINTS (#{entrypoints.size})"
          puts "─" * 70

          entrypoints.each do |ep|
            puts "Namespace URI: #{ep[:namespace] || '—'}"
            puts "File: #{ep[:file]}"
            puts "Role: #{ep[:role]}"
            puts
          end

          puts "DEPENDENCIES (#{dependencies.size})"
          puts "─" * 70

          dependencies.each do |dep|
            puts "#{dep[:file]} (#{dep[:namespace] || '—'})"
          end
          puts
        end

        # Display entrypoint tree
        def display_entrypoint_tree(package, entrypoints, max_depth)
          analyzer = SchemaDependencyAnalyzer.new(package)
          trees = analyzer.build_dependency_tree(entrypoints, depth: max_depth)

          puts
          puts "ENTRYPOINTS & DEPENDENCY TREE"
          puts "═" * 70
          puts

          trees.each do |tree|
            display_tree_node(tree, 0, max_depth)
          end

          puts "━" * 70
          total_deps = count_dependencies(trees)
          puts "Summary: #{entrypoints.size} entrypoint(s) | #{total_deps} dependencies"
          puts
        end

        # Display tree node recursively
        def display_tree_node(node, level, max_depth)
          indent = "   " * level
          marker = level.zero? ? "📄" : "├──"

          puts "#{indent}#{marker} #{node[:file]} #{'⭐ ENTRYPOINT' if level.zero?}"
          puts "#{indent}    URI: #{node[:namespace]}" if node[:namespace]
          puts "#{indent}    (circular ↻)" if node[:circular]

          return if node[:circular]
          return if max_depth && level >= max_depth

          node[:dependencies]&.each do |dep|
            child_indent = "   " * (level + 1)
            puts "#{child_indent}│"
            puts "#{child_indent}#{dep[:type]} → #{dep[:file]}"
            puts "#{child_indent}    URI: #{dep[:namespace]}" if dep[:namespace]

            if dep[:children]
              display_tree_node(dep[:children], level + 2,
                                max_depth)
            end
          end
        end

        # Count total dependencies in tree
        def count_dependencies(trees)
          count = 0
          trees.each do |tree|
            count += count_deps_recursive(tree)
          end
          count
        end

        # Count dependencies recursively
        def count_deps_recursive(node)
          return 0 if node[:circular]

          count = (node[:dependencies] || []).size
          node[:dependencies]&.each do |dep|
            count += count_deps_recursive(dep[:children]) if dep[:children]
          end
          count
        end

        # Display type definition
        def display_type_definition(definition)
          puts
          puts "TYPE DEFINITION: #{definition[:qname]}"
          puts "═" * 70
          puts "Namespace: #{definition[:namespace] || '—'}"
          puts "File: #{definition[:file]}"
          puts "Line: #{definition[:line]}"
          puts "Category: #{definition[:category]}"
          puts
          puts "XSD DEFINITION:"
          puts "─" * 70
          puts definition[:xsd_source]
          puts
        end

        # Display element definition
        def display_element_definition(definition)
          puts
          puts "ELEMENT DEFINITION: #{definition[:qname]}"
          puts "═" * 70
          puts "Namespace: #{definition[:namespace] || '—'}"
          puts "File: #{definition[:file]}"
          puts "Line: #{definition[:line]}"
          puts
          puts "XSD DEFINITION:"
          puts "─" * 70
          puts definition[:xsd_source]
          puts
        end

        # Display attribute definition
        def display_attribute_definition(definition)
          puts
          puts "ATTRIBUTE DEFINITION: #{definition[:qname]}"
          puts "═" * 70
          puts "Namespace: #{definition[:namespace] || '—'}"
          puts "File: #{definition[:file]}"
          puts "Line: #{definition[:line]}"
          puts
          puts "XSD DEFINITION:"
          puts "─" * 70
          puts definition[:xsd_source]
          puts
        end

        # Resolve namespace URI from prefix or full URI
        def resolve_namespace_uri(repository, uri_or_prefix)
          # If it looks like a full URI, return it
          return uri_or_prefix if uri_or_prefix.start_with?("http://", "https://")

          # Otherwise, treat it as a prefix
          mappings = repository.namespace_mappings || []
          mapping = mappings.find { |m| m.prefix == uri_or_prefix }
          mapping&.uri || uri_or_prefix
        end

        # Filter types by namespace
        def filter_types_by_namespace(_repository, namespace_uri)
          types = []

          Lutaml::Xml::Schema::Xsd::Schema.processed_schemas.each_value do |schema|
            next unless schema.target_namespace == namespace_uri

            schema.complex_type.each do |type|
              types << {
                name: type.name,
                category: "ComplexType",
                schema: schema,
              }
            end

            schema.simple_type.each do |type|
              types << {
                name: type.name,
                category: "SimpleType",
                schema: schema,
              }
            end
          end

          types
        end

        # Filter elements by namespace
        def filter_elements_by_namespace(_repository, namespace_uri)
          elements = []

          Lutaml::Xml::Schema::Xsd::Schema.processed_schemas.each_value do |schema|
            next unless schema.target_namespace == namespace_uri

            schema.element.each do |elem|
              elements << {
                name: elem.name,
                type: elem.type,
                schema: schema,
              }
            end
          end

          elements
        end

        # Display namespace types
        def display_namespace_types(namespace_uri, types, format)
          case format
          when "json"
            require "json"
            puts JSON.pretty_generate({
                                        namespace: namespace_uri,
                                        types: types.map do |t|
                                          { name: t[:name],
                                            category: t[:category] }
                                        end,
                                      })
          when "yaml"
            require "yaml"
            puts({
              namespace: namespace_uri,
              types: types.map do |t|
                { name: t[:name], category: t[:category] }
              end,
            }.to_yaml)
          else
            puts
            puts "NAMESPACE: #{namespace_uri}"
            puts "═" * 70
            puts
            puts "TYPES (#{types.size})"
            puts "─" * 70

            types.each do |type|
              puts "#{type[:name]} (#{type[:category]})"
            end
            puts
          end
        end

        # Display namespace elements
        def display_namespace_elements(namespace_uri, elements, format)
          case format
          when "json"
            require "json"
            puts JSON.pretty_generate({
                                        namespace: namespace_uri,
                                        elements: elements.map do |e|
                                          { name: e[:name], type: e[:type] }
                                        end,
                                      })
          when "yaml"
            require "yaml"
            puts({
              namespace: namespace_uri,
              elements: elements.map { |e| { name: e[:name], type: e[:type] } },
            }.to_yaml)
          else
            puts
            puts "NAMESPACE: #{namespace_uri}"
            puts "═" * 70
            puts
            puts "ELEMENTS (#{elements.size})"
            puts "─" * 70

            elements.each do |elem|
              puts "#{elem[:name]} : #{elem[:type] || '(anonymous type)'}"
            end
            puts
          end
        end
      end
    end
  end
end
