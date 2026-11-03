# frozen_string_literal: true

require "thor"
require_relative "base_command"
require_relative "../dependency_grapher"
require_relative "../batch_type_query"

module Lutaml
  module Xsd
    module Commands
      # Type query commands
      # Handles finding and listing schema types
      class TypeCommand < Thor
        # Command aliases
        map "f" => :find
        map "ls" => :list

        class_option :verbose,
                     type: :boolean,
                     default: false,
                     desc: "Enable verbose output"

        desc "find QNAME PACKAGE", "Find type(s) - supports batch mode"
        long_desc <<~DESC
          Find and display type information.

          Single mode:
            lutaml-xsd type find "gml:CodeType" schemas.lxr

          Batch mode from file:
            lutaml-xsd type find --batch-file types.txt schemas.lxr

          Batch mode from stdin:
            echo "Type1\\nType2" | lutaml-xsd type find --batch schemas.lxr
        DESC
        option :batch, type: :boolean, desc: "Read types from stdin"
        option :batch_file, type: :string, desc: "Read types from file"
        option :format,
               type: :string,
               default: "text",
               enum: %w[text json yaml],
               desc: "Output format"
        def find(qname_or_package = nil, package_path = nil)
          # Handle both single and batch modes
          if options[:batch] || options[:batch_file]
            # Batch mode: qname_or_package is actually the package path
            BatchFindCommand.new(qname_or_package, options).run
          else
            # Single mode: original behavior
            FindCommand.new(qname_or_package, package_path, options).run
          end
        end

        desc "list PACKAGE_FILE", "List all types in the repository"
        long_desc <<~DESC
          List all types in a schema repository package.

          Examples:
            # List all types
            lutaml-xsd type list my-schemas.lxr

            # List types in a specific namespace
            lutaml-xsd type list my-schemas.lxr --namespace http://www.example.com

            # List types of a specific category
            lutaml-xsd type list my-schemas.lxr --category complex_type
        DESC
        option :namespace,
               type: :string,
               desc: "Filter by namespace URI"
        option :category,
               type: :string,
               enum: %w[element complex_type simple_type attribute_group group],
               desc: "Filter by type category"
        option :format,
               type: :string,
               default: "text",
               enum: %w[text json yaml],
               desc: "Output format"
        def list(package_file)
          ListCommand.new(package_file, options).run
        end

        desc "dependencies QNAME PACKAGE", "Show what a type depends on"
        long_desc <<~DESC
          Analyze and display the dependency graph for a type, showing what other
          types it depends on. Supports multiple output formats including text,
          Mermaid diagrams, DOT (Graphviz), JSON, and YAML.

          Examples:
            # Show dependencies in text format
            lutaml-xsd type dependencies "unitsml:UnitType" unitsml-auto.lxr

            # Generate Mermaid diagram
            lutaml-xsd type dependencies "gml:PointType" gml.lxr --format mermaid

            # Limit recursion depth
            lutaml-xsd type dependencies "gml:PointType" gml.lxr --depth 2

            # Export as DOT for Graphviz
            lutaml-xsd type dependencies "gml:PointType" gml.lxr --format dot > deps.dot
        DESC
        option :depth,
               type: :numeric,
               default: 3,
               desc: "Maximum recursion depth for dependency traversal"
        option :format,
               type: :string,
               default: "text",
               enum: %w[text mermaid dot json yaml],
               desc: "Output format"
        option :direction,
               type: :string,
               default: "both",
               enum: %w[both up down],
               desc: "Direction to show (both=full graph, down=dependencies only)"
        def dependencies(qname, package_path)
          DependenciesCommand.new(qname, package_path, options).run
        end

        desc "dependents QNAME PACKAGE", "Show what depends on a type"
        long_desc <<~DESC
          Find and display all types that depend on (reference) the specified type.
          This reverse dependency analysis helps understand the impact of changes.

          Examples:
            # Show all types that depend on SystemType
            lutaml-xsd type dependents "unitsml:SystemType" unitsml-auto.lxr

            # Export as JSON
            lutaml-xsd type dependents "gml:CodeType" gml.lxr --format json

            # Show with verbose details
            lutaml-xsd type dependents "gml:CodeType" gml.lxr --verbose
        DESC
        option :format,
               type: :string,
               default: "text",
               enum: %w[text json yaml],
               desc: "Output format"
        def dependents(qname, package_path)
          DependentsCommand.new(qname, package_path, options).run
        end

        desc "hierarchy QNAME PACKAGE", "Show type inheritance hierarchy"
        long_desc <<~DESC
          Display the inheritance hierarchy for a type, showing both ancestors
          (base types) and descendants (derived types).

          Examples:
            # Show hierarchy in text format
            lutaml-xsd type hierarchy "gml:AbstractFeatureType" schemas.lxr

            # Limit depth
            lutaml-xsd type hierarchy "gml:AbstractFeatureType" schemas.lxr --depth 5

            # Show only ancestors
            lutaml-xsd type hierarchy "gml:AbstractFeatureType" schemas.lxr --direction ancestors

            # Generate Mermaid diagram
            lutaml-xsd type hierarchy "gml:AbstractFeatureType" schemas.lxr --format mermaid

            # Export as JSON
            lutaml-xsd type hierarchy "gml:AbstractFeatureType" schemas.lxr --format json
        DESC
        option :depth,
               type: :numeric,
               default: 10,
               desc: "Maximum depth to traverse"
        option :direction,
               type: :string,
               default: "both",
               enum: %w[ancestors descendants both],
               desc: "Direction to show (ancestors=base types, descendants=derived types, both=full hierarchy)"
        option :format,
               type: :string,
               default: "text",
               enum: %w[text mermaid json yaml],
               desc: "Output format"
        def hierarchy(qname, package_path)
          HierarchyCommand.new(qname, package_path, options).run
        end

        # Command aliases
        map "deps" => :dependencies
        map "uses" => :dependents
        map "h" => :hierarchy

        # Find command implementation
        class FindCommand < BaseCommand
          def initialize(qname, package_file, options)
            super(options)
            @qname = qname
            @package_file = package_file
          end

          def run
            @repository = load_repository(@package_file)
            @repository = ensure_resolved(@repository)

            find_and_display_type(@repository)
          end

          private

          def find_and_display_type(repository)
            if verbose?
              output "🔍 Resolving type: #{@qname}"
              output "  Parsing qualified name..."
              output "  Checking namespace registry..."
              output "  Searching type index..."
              output ""
            end

            result = repository.find_type(@qname)

            if verbose? && result.resolved?
              output "📊 Resolution Details:"
              output "  Found in type index: #{result.definition.class.name}"
              output "  Namespace: #{result.namespace}"
              output "  Schema: #{result.schema_file}"
              if result.resolution_path
                output "  Resolution steps: #{result.resolution_path.size}"
                result.resolution_path.each_with_index do |step, i|
                  output "    #{i + 1}. #{step}"
                end
              end
              output ""
            end

            format = options[:format] || "text"

            case format
            when "json", "yaml"
              output format_output(result_to_hash(result), format)
            else
              display_text_result(result)
            end

            raise CommandError unless result.resolved?
          end

          def result_to_hash(result)
            hash = {
              resolved: result.resolved?,
              qname: result.qname,
            }

            if result.resolved?
              hash[:namespace] = result.namespace
              hash[:local_name] = result.local_name
              hash[:schema_file] = result.schema_file
              hash[:resolution_path] = result.resolution_path
              hash[:definition_class] = result.definition.class.name
            else
              hash[:error_message] = result.error_message
              if result.resolution_path
                hash[:resolution_path] =
                  result.resolution_path
              end
            end

            hash
          end

          def display_text_result(result)
            output "=" * 80
            output "Type Resolution: #{@qname}"
            output "=" * 80
            output ""

            if result.resolved?
              display_resolved_type(result)
            else
              display_failed_resolution(result)
            end
          end

          def display_resolved_type(result)
            require "table_tennis"

            output "✓ Type found"
            output ""

            # Extract documentation first
            doc = extract_documentation(result.definition)
            doc = "(no documentation)" if doc.nil? || doc.strip.empty?

            # Metadata table with documentation included
            metadata_table = TableTennis.new(
              [
                { "Property" => "Qualified Name", "Value" => result.qname },
                { "Property" => "Namespace",
                  "Value" => result.namespace || "(none)" },
                { "Property" => "Local Name", "Value" => result.local_name },
                { "Property" => "Schema File",
                  "Value" => File.basename(result.schema_file) },
                { "Property" => "Type Class",
                  "Value" => result.definition.class.name },
                { "Property" => "Documentation", "Value" => doc },
              ],
            )

            output metadata_table
            output ""

            # Always show complete type structure
            display_type_structure(result.definition, @repository)

            # Always show drill-down hints
            display_drill_down_hints(result.definition, @repository)
          end

          def display_failed_resolution(result)
            output "✗ Type not found"
            output ""
            output "Error: #{result.error_message}"

            return unless result.resolution_path && !result.resolution_path.empty?

            output ""
            output "Resolution Path:"
            result.resolution_path.each_with_index do |step, idx|
              output "  #{idx + 1}. #{step}"
            end
          end

          def display_type_structure(definition, repository)
            # Display simple content
            if definition.simple_content
              display_simple_content(definition.simple_content,
                                     repository)
            end

            # Display complex content
            if definition.complex_content
              display_complex_content(definition.complex_content,
                                      repository)
            end

            # Display sequence elements
            if definition.sequence
              display_sequence(definition.sequence,
                               repository)
            end

            # Display choice elements
            if definition.choice
              display_choice(definition.choice,
                             repository)
            end

            # Display all elements
            if definition.all
              display_all(definition.all,
                          repository)
            end

            # Display direct attributes
            if definition.attribute
              display_attributes(definition.attribute, repository,
                                 "Attributes")
            end

            # Display attribute groups
            display_attribute_groups(definition.attribute_group) if definition.attribute_group
          end

          def display_simple_content(simple_content, repository)
            output "Simple Content:"

            return unless simple_content.extension

            extension = simple_content.extension
            output "  Extension:"
            output "    Base: #{extension.base}" if extension.base

            return unless extension.attribute

            display_attributes(extension.attribute, repository,
                               "    Attributes", indent: "    ")
          end

          def display_complex_content(complex_content, repository)
            output "Complex Content:"

            if complex_content.extension
              extension = complex_content.extension
              output "  Extension:"
              output "    Base: #{extension.base}" if extension.base

              # Display sequence from extension
              if extension.sequence
                display_sequence(extension.sequence, repository,
                                 indent: "    ")
              end

              # Display attributes from extension
              if extension.attribute
                display_attributes(extension.attribute, repository, "    Attributes",
                                   indent: "    ")
              end

              # Display attribute groups from extension
              if extension.attribute_group
                display_attribute_groups(extension.attribute_group,
                                         indent: "    ")
              end
            end

            return unless complex_content.restriction

            restriction = complex_content.restriction
            output "  Restriction:"
            output "    Base: #{restriction.base}" if restriction.base

            # Display sequence from restriction
            if restriction.sequence
              display_sequence(restriction.sequence, repository,
                               indent: "    ")
            end

            # Display attributes from restriction
            return unless restriction.attribute

            display_attributes(restriction.attribute, repository, "    Attributes",
                               indent: "    ")
          end

          def display_sequence(sequence, repository, indent: "")
            return unless sequence&.element && !sequence.element.empty?

            require "table_tennis"

            output "#{indent}Sequence:"

            elements = sequence.element.is_a?(Array) ? sequence.element : [sequence.element]
            elements = elements.compact

            elements_data = elements.map do |elem|
              name = elem.ref || elem.name || "(unknown)"
              resolution = resolve_element_with_path(elem, repository)
              min = elem.min_occurs || "1"
              max = elem.max_occurs || "1"
              max = "*" if max == "unbounded"
              doc = extract_documentation(elem)

              # Build type display
              type_display = if resolution[:resolved]
                               resolution[:type] || "(inline)"
                             else
                               "\e[31m⚠️  UNRESOLVED\e[0m"
                             end

              # Combine documentation + path
              combined_doc = if doc && !doc.empty?
                               doc
                             else
                               ""
                             end

              # Add path info on new line
              if resolution[:path_info] && resolution[:path_info] != "inline"
                path_line = "Path: #{resolution[:path_info]}"
                combined_doc = combined_doc.empty? ? path_line : "#{combined_doc}\n#{path_line}"
              end

              {
                "Element" => name,
                "Type" => type_display,
                "Cardinality" => "[#{min}..#{max}]",
                "Documentation" => combined_doc,
              }
            end

            table = TableTennis.new(elements_data)

            table.to_s.split("\n").each do |line|
              output "#{indent}#{line}"
            end
            output ""
          end

          def display_choice(choice, repository, indent: "")
            return unless choice&.element && !choice.element.empty?

            require "table_tennis"

            output "#{indent}Choice:"

            elements = choice.element.is_a?(Array) ? choice.element : [choice.element]
            elements = elements.compact

            elements_data = elements.map do |elem|
              name = elem.ref || elem.name || "(unknown)"
              resolution = resolve_element_with_path(elem, repository)
              min = elem.min_occurs || "1"
              max = elem.max_occurs || "1"
              max = "*" if max == "unbounded"
              doc = extract_documentation(elem)

              # Build type display
              type_display = if resolution[:resolved]
                               resolution[:type] || "(inline)"
                             else
                               "\e[31m⚠️  UNRESOLVED\e[0m"
                             end

              # Combine documentation + path
              combined_doc = if doc && !doc.empty?
                               doc
                             else
                               ""
                             end

              # Add path info on new line
              if resolution[:path_info] && resolution[:path_info] != "inline"
                path_line = "Path: #{resolution[:path_info]}"
                combined_doc = combined_doc.empty? ? path_line : "#{combined_doc}\n#{path_line}"
              end

              {
                "Element" => name,
                "Type" => type_display,
                "Cardinality" => "[#{min}..#{max}]",
                "Documentation" => combined_doc,
              }
            end

            table = TableTennis.new(elements_data)

            table.to_s.split("\n").each do |line|
              output "#{indent}#{line}"
            end
            output ""
          end

          def display_all(all, repository, indent: "")
            return unless all&.element && !all.element.empty?

            require "table_tennis"

            output "#{indent}All:"

            elements = all.element.is_a?(Array) ? all.element : [all.element]
            elements = elements.compact

            elements_data = elements.map do |elem|
              name = elem.ref || elem.name || "(unknown)"
              resolution = resolve_element_with_path(elem, repository)
              min = elem.min_occurs || "1"
              max = elem.max_occurs || "1"
              max = "*" if max == "unbounded"
              doc = extract_documentation(elem)

              # Build type display
              type_display = if resolution[:resolved]
                               resolution[:type] || "(inline)"
                             else
                               "\e[31m⚠️  UNRESOLVED\e[0m"
                             end

              # Combine documentation + path
              combined_doc = if doc && !doc.empty?
                               doc
                             else
                               ""
                             end

              # Add path info on new line
              if resolution[:path_info] && resolution[:path_info] != "inline"
                path_line = "Path: #{resolution[:path_info]}"
                combined_doc = combined_doc.empty? ? path_line : "#{combined_doc}\n#{path_line}"
              end

              {
                "Element" => name,
                "Type" => type_display,
                "Cardinality" => "[#{min}..#{max}]",
                "Documentation" => combined_doc,
              }
            end

            table = TableTennis.new(elements_data)

            table.to_s.split("\n").each do |line|
              output "#{indent}#{line}"
            end
            output ""
          end

          def display_attributes(attributes, repository, label = "Attributes",
indent: "")
            attrs = attributes.is_a?(Array) ? attributes : [attributes]
            attrs = attrs.compact
            return if attrs.empty?

            require "table_tennis"

            output "#{indent}#{label}:"

            attrs_data = attrs.map do |attr|
              attr_name = attr.ref || attr.name || "(unknown)"
              resolution = resolve_attribute_with_path(attr, repository)
              use = attr.use || "optional"
              doc = extract_documentation(attr)

              # Type display with source info
              if resolution[:resolved]
                type_display = resolution[:type]
                if resolution[:source_schema] != "inline" && resolution[:source_schema] != "unknown"
                  source = File.basename(resolution[:source_schema])
                  type_display = "#{resolution[:type]} (from #{source})"
                end
              else
                type_display = "\e[31m⚠️  UNRESOLVED\e[0m"
              end

              # Combine doc + path
              combined_doc = doc || ""
              if resolution[:path_info] && resolution[:path_info] != "inline definition"
                path_line = "Path: #{resolution[:path_info]}"
                combined_doc = combined_doc.empty? ? path_line : "#{combined_doc}\n#{path_line}"
              end

              {
                "Attribute" => attr_name,
                "Type" => type_display,
                "Usage" => use,
                "Documentation" => combined_doc,
              }
            end

            table = TableTennis.new(attrs_data)

            table.to_s.split("\n").each do |line|
              output "#{indent}#{line}"
            end
            output ""
          end

          def resolve_attribute_type(attr, repository)
            resolution = resolve_attribute_with_path(attr, repository)
            resolution[:type]
          end

          def resolve_attribute_with_path(attr, repository)
            if attr.ref
              # It's a reference like "xml:id" - find the actual attribute definition
              attr_def = repository.find_attribute(attr.ref)
              if attr_def
                # Find which schema contains this attribute
                source_schema = find_schema_for_attribute(attr_def, repository)

                # Build path info
                if source_schema&.location && source_schema.location != "unknown"
                  source = File.basename(source_schema.location)
                  path_info = "ref '#{attr.ref}' → #{source} → type '#{attr_def.type}'"
                else
                  path_info = "ref '#{attr.ref}' → type '#{attr_def.type}'"
                end

                {
                  type: attr_def.type,
                  resolved: true,
                  source_schema: source_schema&.location || "unknown",
                  resolution_method: "cross-schema import",
                  ref: attr.ref,
                  path_info: path_info,
                }
              else
                {
                  type: nil,
                  resolved: false,
                  resolution_method: "not found",
                  ref: attr.ref,
                  path_info: "NOT FOUND",
                }
              end
            else
              {
                type: attr.type,
                resolved: true,
                source_schema: "inline",
                resolution_method: "direct",
                path_info: "inline definition",
              }
            end
          end

          def find_schema_for_attribute(attr, repository)
            parsed_schemas = repository.instance_variable_get(:@parsed_schemas)
            return nil unless parsed_schemas

            parsed_schemas.all.each_value do |schema|
              next if schema.attribute.empty?

              attrs = schema.attribute
              attrs = [attrs] unless attrs.is_a?(Array)
              return schema if attrs.compact.include?(attr)
            end
            nil
          end

          def resolve_element_with_path(elem, repository)
            if elem.ref
              # It's a reference to a global element
              elem_def = repository.find_element(elem.ref)
              if elem_def
                # Found the element definition
                source_schema = find_schema_for_element(elem_def, repository)

                # Build path info
                path_info = if elem_def.type && source_schema&.location != "inline"
                              "ref '#{elem.ref}' → element → type '#{elem_def.type}'"
                            else
                              "inline"
                            end

                {
                  type: elem_def.type || "(inline complex type)",
                  resolved: true,
                  source_schema: source_schema&.location || "unknown",
                  resolution_method: elem_def.type ? "element reference" : "inline definition",
                  path_info: path_info,
                }
              else
                {
                  type: nil,
                  resolved: false,
                  resolution_method: "element not found",
                  path_info: "NOT FOUND",
                }
              end
            elsif elem.type
              # Direct type reference
              {
                type: elem.type,
                resolved: true,
                source_schema: "inline",
                resolution_method: "direct",
                path_info: "inline",
              }
            else
              # Inline complex or simple type
              {
                type: "(inline type definition)",
                resolved: true,
                source_schema: "inline",
                resolution_method: "inline",
                path_info: "inline",
              }
            end
          end

          def find_schema_for_element(elem, repository)
            parsed_schemas = repository.instance_variable_get(:@parsed_schemas)
            return nil unless parsed_schemas

            parsed_schemas.all.each_value do |schema|
              next if schema.element.empty?

              elements = schema.element
              elements = [elements] unless elements.is_a?(Array)
              return schema if elements.compact.include?(elem)
            end
            nil
          end

          def display_attribute_groups(groups, indent: "")
            return unless groups && !groups.empty?

            require "table_tennis"

            groups = [groups] unless groups.is_a?(Array)
            groups = groups.compact
            return if groups.empty?

            output "#{indent}Attribute Groups:"

            groups_data = groups.map do |group|
              name = group.ref || group.name || "(unknown)"
              doc = extract_documentation(group)

              {
                "Group" => name,
                "Documentation" => doc,
              }
            end

            table = TableTennis.new(groups_data)

            table.to_s.split("\n").each do |line|
              output "#{indent}#{line}"
            end
            output ""
          end

          def extract_documentation(obj)
            return "" unless obj.annotation&.documentation

            docs = obj.annotation.documentation
            docs = [docs] unless docs.is_a?(Array)

            docs.filter_map do |doc|
              content = doc.content || doc.to_s
              content&.strip
            end.first || ""
          end

          def display_drill_down_hints(definition, repository)
            output ""
            output "💡 Explore further:"
            output ""

            hints = []

            # Collect hints from sequence elements
            if definition.sequence
              definition.sequence.element.first(3).each do |elem|
                ref = elem.ref || elem.name
                type = nil

                # Resolve the type for this element
                if elem.type
                  type = elem.type
                elsif elem.ref
                  # Look up the referenced element to get its type
                  elem_def = repository.find_element(elem.ref)
                  type = elem_def.type if elem_def.type
                end

                next if !type || type == "(inline)" || type =~ /^xsd?:/

                hints << {
                  element: ref,
                  type: type,
                  command: "lutaml-xsd type find \"#{type}\" <package-file>",
                }
              end
            end

            # Collect hints from choice elements
            if definition.choice
              definition.choice.element.first(3).each do |elem|
                ref = elem.ref || elem.name
                type = nil

                # Resolve the type for this element
                if elem.type
                  type = elem.type
                elsif elem.ref
                  # Look up the referenced element to get its type
                  elem_def = repository.find_element(elem.ref)
                  type = elem_def.type if elem_def.type
                end

                next if !type || type == "(inline)" || type =~ /^xsd?:/

                hints << {
                  element: ref,
                  type: type,
                  command: "lutaml-xsd type find \"#{type}\" <package-file>",
                }
              end
            end

            # Collect hints from complex content extensions
            if definition.complex_content&.extension
              extension = definition.complex_content.extension
              if extension.base && extension.base !~ /^xsd?:/
                hints << {
                  element: "base type",
                  type: extension.base,
                  command: "lutaml-xsd type find \"#{extension.base}\" <package-file>",
                }
              end

              # Also check sequence in extension
              if extension.sequence
                extension.sequence.element.first(2).each do |elem|
                  ref = elem.ref || elem.name
                  type = elem.type || "(inline)"
                  next if type == "(inline)" || type =~ /^xsd?:/

                  hints << {
                    element: ref,
                    type: type,
                    command: "lutaml-xsd type find \"#{type}\" <package-file>",
                  }
                end
              end
            end

            # Collect hints from simple content extensions
            if definition.simple_content&.extension
              extension = definition.simple_content.extension
              if extension.base && extension.base !~ /^xsd?:/
                hints << {
                  element: "base type",
                  type: extension.base,
                  command: "lutaml-xsd type find \"#{extension.base}\" <package-file>",
                }
              end
            end

            # Display unique hints
            hints.uniq { |h| h[:type] }.first(5).each do |hint|
              output "  To explore #{hint[:element]} (#{hint[:type]}):"
              output "    #{hint[:command]}"
              output ""
            end

            return unless hints.empty?

            output "  (No explorable types found in this definition)"
            output ""
          end
        end

        # List command implementation
        class ListCommand < BaseCommand
          def initialize(package_file, options)
            super(options)
            @package_file = package_file
          end

          def run
            repository = load_repository(@package_file)
            repository = ensure_resolved(repository)

            list_types(repository)
          end

          private

          def list_types(repository)
            stats = repository.statistics
            types_by_category = stats[:types_by_category] || {}

            # Filter by category if specified
            if options[:category]
              category_sym = options[:category].to_sym
              types_by_category = if types_by_category.key?(category_sym)
                                    { category_sym => types_by_category[category_sym] }
                                  else
                                    {}
                                  end
            end

            format = options[:format] || "text"

            case format
            when "json", "yaml"
              output format_output(types_by_category, format)
            else
              display_text_list(types_by_category, stats)
            end
          end

          def display_text_list(types_by_category, stats)
            require "table_tennis"

            output "Schema Repository Type Listing"
            output "=" * 80
            output ""
            output "Total Types: #{stats[:total_types]}"
            output "Total Namespaces: #{stats[:total_namespaces]}"

            output "Filtered by Namespace: #{options[:namespace]}" if options[:namespace]

            output "Filtered by Category: #{options[:category]}" if options[:category]

            output ""
            output "Types by Category:"
            output "-" * 80

            # Build table data as array of hashes
            category_data = types_by_category.sort.map do |category, count|
              { "Category" => category.to_s, "Count" => count }
            end

            category_table = TableTennis.new(category_data)
            output category_table

            output ""
            output "Note: Use 'lutaml-xsd type find <qname> <package>' to get details about a specific type"
          end
        end

        # Dependencies command implementation
        class DependenciesCommand < BaseCommand
          def initialize(qname, package_path, options)
            super(options)
            @qname = qname
            @package_path = package_path
          end

          def run
            repository = load_repository(@package_path)
            repository = ensure_resolved(repository)

            display_dependencies(repository)
          end

          private

          def display_dependencies(repository)
            grapher = DependencyGrapher.new(repository)
            depth = options[:depth] || 3
            graph = grapher.dependencies(@qname, depth: depth)

            unless graph[:resolved]
              error "Failed to resolve type: #{@qname}"
              output ""
              output graph[:error]
              raise CommandError
            end

            format = options[:format] || "text"
            direction = options[:direction] || "both"

            case format
            when "json"
              output JSON.pretty_generate(graph)
            when "yaml"
              output graph.to_yaml
            when "mermaid"
              output grapher.to_mermaid(graph)
            when "dot"
              output grapher.to_dot(graph)
            else
              display_text_graph(graph, grapher, direction)
            end
          end

          def display_text_graph(graph, _grapher, _direction)
            require "table_tennis"

            output "=" * 80
            output "Type Dependency Analysis: #{graph[:root]}"
            output "=" * 80
            output ""

            metadata = [
              { "Property" => "Type", "Value" => graph[:root] },
              { "Property" => "Namespace",
                "Value" => graph[:namespace] || "(none)" },
              { "Property" => "Category", "Value" => graph[:type_category] },
              { "Property" => "Dependencies Found",
                "Value" => count_dependencies(graph[:dependencies]).to_s },
            ]

            table = TableTennis.new(metadata)
            output table
            output ""

            if graph[:dependencies].empty?
              output "No dependencies found (type may be a primitive or self-contained type)"
            else
              output "Dependencies (what this type depends on):"
              output "-" * 80
              output ""
              display_dependency_tree(graph[:dependencies], "")
            end

            return if graph[:dependencies].empty?

            output ""
            output "💡 Tip: Use --format mermaid or --format dot to generate diagrams"
            output "💡 Tip: Adjust --depth to control recursion level (current: #{options[:depth] || 3})"
          end

          def display_dependency_tree(deps, indent)
            deps.each_with_index do |(dep_name, dep_info), index|
              is_last = index == deps.size - 1
              connector = is_last ? "└─" : "├─"
              continuation = is_last ? "   " : "│  "

              output "#{indent}#{connector} #{dep_name}"
              output "#{indent}#{continuation}└─ Category: #{dep_info[:type_category]}"
              output "#{indent}#{continuation}└─ Schema: #{dep_info[:schema_file]}"

              if dep_info[:dependencies] && !dep_info[:dependencies].empty?
                output "#{indent}#{continuation}└─ Dependencies:"
                display_dependency_tree(dep_info[:dependencies],
                                        "#{indent}#{continuation}   ")
              end

              output "#{indent}│" unless is_last
            end
          end

          def count_dependencies(deps)
            count = deps.size
            deps.each_value do |dep_info|
              count += count_dependencies(dep_info[:dependencies]) if dep_info[:dependencies]
            end
            count
          end
        end

        # Dependents command implementation
        class DependentsCommand < BaseCommand
          def initialize(qname, package_path, options)
            super(options)
            @qname = qname
            @package_path = package_path
          end

          def run
            repository = load_repository(@package_path)
            repository = ensure_resolved(repository)

            display_dependents(repository)
          end

          private

          def display_dependents(repository)
            grapher = DependencyGrapher.new(repository)
            result = grapher.dependents(@qname)

            unless result[:resolved]
              error "Failed to resolve type: #{@qname}"
              output ""
              output result[:error]
              raise CommandError
            end

            format = options[:format] || "text"

            case format
            when "json"
              output JSON.pretty_generate(result)
            when "yaml"
              output result.to_yaml
            else
              display_text_dependents(result)
            end
          end

          def display_text_dependents(result)
            require "table_tennis"

            output "=" * 80
            output "Type Dependents Analysis: #{result[:target]}"
            output "=" * 80
            output ""

            output "Target Type: #{result[:target]}"
            output "Namespace: #{result[:namespace] || '(none)'}"
            output "Dependents Found: #{result[:count]}"
            output ""

            if result[:dependents].empty?
              output "No types depend on this type."
              output ""
              output "This type is either:"
              output "  - Not referenced by any other types in the repository"
              output "  - A leaf type in the dependency graph"
              output "  - An unused type definition"
            else
              output "Types that depend on #{result[:target]}:"
              output "-" * 80
              output ""

              # Group by category
              by_category = result[:dependents].group_by do |d|
                d[:type_category]
              end

              by_category.sort.each do |category, deps|
                output "#{category.upcase} (#{deps.size}):"
                output ""

                deps_data = deps.map do |dep|
                  {
                    "Qualified Name" => dep[:qname],
                    "Namespace" => dep[:namespace] || "(none)",
                    "Schema File" => dep[:schema_file],
                  }
                end

                table = TableTennis.new(deps_data)
                output table
                output ""
              end

              output "💡 Tip: Use 'lutaml-xsd type dependencies <qname>' to see what each type depends on"
            end
          end
        end

        # Hierarchy command implementation
        class HierarchyCommand < BaseCommand
          def initialize(qname, package_path, options)
            super(options)
            @qname = qname
            @package_path = package_path
          end

          def run
            repository = load_repository(@package_path)
            repository = ensure_resolved(repository)

            display_hierarchy(repository)
          end

          private

          def display_hierarchy(repository)
            hierarchy = repository.analyze_type_hierarchy(@qname,
                                                          depth: options[:depth] || 10)

            unless hierarchy
              error "Failed to resolve type: #{@qname}"
              raise CommandError
            end

            format = options[:format] || "text"
            direction = options[:direction] || "both"

            case format
            when "json"
              output JSON.pretty_generate(filter_by_direction(hierarchy,
                                                              direction))
            when "yaml"
              output filter_by_direction(hierarchy, direction).to_yaml
            when "mermaid"
              output hierarchy[:formats][:mermaid]
            else
              display_text_hierarchy(hierarchy, direction)
            end
          end

          def display_text_hierarchy(hierarchy, direction)
            require "table_tennis"

            output "=" * 80
            output "Type Inheritance Hierarchy: #{hierarchy[:root]}"
            output "=" * 80
            output ""

            # Metadata table
            metadata = [
              { "Property" => "Qualified Name", "Value" => hierarchy[:root] },
              { "Property" => "Namespace",
                "Value" => hierarchy[:namespace] || "(none)" },
              { "Property" => "Local Name", "Value" => hierarchy[:local_name] },
              { "Property" => "Category",
                "Value" => hierarchy[:type_category].to_s },
            ]

            if %w[
              both ancestors
            ].include?(direction)
              metadata << { "Property" => "Ancestors Found",
                            "Value" => hierarchy[:ancestors].size.to_s }
            end

            if %w[
              both descendants
            ].include?(direction)
              metadata << { "Property" => "Descendants Found",
                            "Value" => hierarchy[:descendants].size.to_s }
            end

            table = TableTennis.new(metadata)
            output table
            output ""

            # Display ancestors (base types)
            if %w[both
                  ancestors].include?(direction) && !hierarchy[:ancestors].empty?
              output "Ancestors (Base Types):"
              output "-" * 80
              output ""
              display_type_list(hierarchy[:ancestors], "  ↑")
              output ""
            end

            # Display descendants (derived types)
            if %w[both
                  descendants].include?(direction) && !hierarchy[:descendants].empty?
              output "Descendants (Derived Types):"
              output "-" * 80
              output ""
              display_type_list(hierarchy[:descendants], "  ↓")
              output ""
            end

            # Show tree visualization
            if direction == "both"
              output "Tree Visualization:"
              output "-" * 80
              output ""
              output hierarchy[:formats][:text]
              output ""
            end

            # Tips
            output "💡 Tips:"
            output "  - Use --format mermaid to generate diagram syntax"
            output "  - Use --direction ancestors to show only base types"
            output "  - Use --direction descendants to show only derived types"
            output "  - Use --depth N to control traversal depth"
          end

          def display_type_list(types, prefix)
            types.each do |type_info|
              output "#{prefix} #{type_info[:qualified_name]}"
              output "     Category: #{type_info[:type_category]}"
              output "     Namespace: #{type_info[:namespace] || '(none)'}"
              output ""
            end
          end

          def filter_by_direction(hierarchy, direction)
            case direction
            when "ancestors"
              hierarchy.slice(:root, :namespace, :local_name, :type_category,
                              :ancestors)
            when "descendants"
              hierarchy.slice(:root, :namespace, :local_name, :type_category,
                              :descendants)
            else
              hierarchy
            end
          end
        end

        # Batch find command implementation
        class BatchFindCommand < BaseCommand
          def initialize(package_file, options)
            super(options)
            @package_file = package_file
          end

          def run
            unless @package_file
              error "Package file path is required for batch mode"
              raise CommandError
            end

            @repository = load_repository(@package_file)
            @repository = ensure_resolved(@repository)

            execute_batch_query
          end

          private

          def execute_batch_query
            batch_query = BatchTypeQuery.new(@repository)

            # Execute based on input source
            results = if options[:batch_file]
                        batch_query.execute_from_file(options[:batch_file])
                      elsif options[:batch]
                        batch_query.execute_from_stdin
                      else
                        error "Either --batch or --batch-file must be specified"
                        raise CommandError
                      end

            # Display results
            format = options[:format] || "text"

            case format
            when "json"
              display_json_results(results)
            when "yaml"
              display_yaml_results(results)
            else
              display_text_results(results)
            end

            # Exit with error if any query failed
            raise CommandError if results.any? { |r| !r.resolved }
          end

          def display_text_results(results)
            require "table_tennis"

            output "=" * 80
            output "Batch Type Query Results"
            output "=" * 80
            output ""
            output "Total Queries: #{results.size}"
            output "Resolved: #{results.count(&:resolved)}"
            output "Failed: #{results.count { |r| !r.resolved }}"
            output ""

            # Create table data
            table_data = results.map do |result|
              {
                "Query" => result.query,
                "Status" => result.resolved ? "✓" : "✗",
                "Qualified Name" => result.result.qname,
                "Namespace" => result.result.namespace || "(none)",
                "Type Class" => result.resolved ? result.result.definition.class.name.split("::").last : "N/A",
              }
            end

            table = TableTennis.new(table_data)
            output table
            output ""

            # Show failed queries details
            failed = results.reject(&:resolved)
            return if failed.empty?

            output "Failed Queries:"
            output "-" * 80
            failed.each do |result|
              output "  Query: #{result.query}"
              output "  Error: #{result.result.error_message}"
              output ""
            end
          end

          def display_json_results(results)
            require "json"

            data = {
              total: results.size,
              resolved: results.count(&:resolved),
              failed: results.count { |r| !r.resolved },
              results: results.map(&:to_h),
            }

            output JSON.pretty_generate(data)
          end

          def display_yaml_results(results)
            require "yaml"

            data = {
              "total" => results.size,
              "resolved" => results.count(&:resolved),
              "failed" => results.count { |r| !r.resolved },
              "results" => results.map(&:to_h),
            }

            output data.to_yaml
          end
        end
      end
    end
  end
end
