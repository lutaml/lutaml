# frozen_string_literal: true

require "thor"
require_relative "base_command"

module Lutaml
  module Xsd
    module Commands
      # Element exploration commands
      # Handles listing, showing, and analyzing element definitions
      class ElementCommand < Thor
        # Command aliases
        map "ls" => :list
        map "s" => :show
        map "t" => :tree
        map "u" => :usage

        class_option :verbose,
                     type: :boolean,
                     default: false,
                     desc: "Enable verbose output"

        desc "list PACKAGE_FILE", "List all elements in the repository"
        long_desc <<~DESC
          List all top-level element definitions in the schema repository.
          Elements can be filtered by namespace.

          Examples:
            # List all elements
            lutaml-xsd element list pkg.lxr

            # List elements in a specific namespace
            lutaml-xsd element list pkg.lxr --namespace http://www.opengis.net/gml/3.2

            # List elements in JSON format
            lutaml-xsd element list pkg.lxr --format json
        DESC
        option :namespace,
               type: :string,
               desc: "Filter by namespace URI"
        option :format,
               type: :string,
               default: "text",
               enum: %w[text json yaml],
               desc: "Output format"
        def list(package_file)
          ListCommand.new(package_file, options).run
        end

        desc "show ELEMENT_NAME PACKAGE_FILE",
             "Show details about a specific element"
        long_desc <<~DESC
          Display detailed information about a specific element including its type,
          attributes, and documentation.

          ELEMENT_NAME can be:
            - Qualified name with prefix: gml:Point
            - Clark notation: {http://www.opengis.net/gml/3.2}Point
            - Local name (if unambiguous): Point

          Examples:
            # Show element details
            lutaml-xsd element show gml:Point pkg.lxr

            # Show element with type details
            lutaml-xsd element show gml:Point pkg.lxr --show-type

            # Show element with attributes
            lutaml-xsd element show gml:Point pkg.lxr --show-attributes
        DESC
        option :show_type,
               type: :boolean,
               default: true,
               desc: "Show the element's type definition"
        option :show_attributes,
               type: :boolean,
               default: true,
               desc: "Show element attributes"
        def show(element_name, package_file)
          ShowCommand.new(element_name, package_file, options).run
        end

        desc "tree ELEMENT_NAME PACKAGE_FILE", "Show element structure tree"
        long_desc <<~DESC
          Display the nested structure of an element showing its composition
          and child elements.

          Examples:
            # Show element tree
            lutaml-xsd element tree gml:Point pkg.lxr

            # Limit tree depth
            lutaml-xsd element tree gml:Point pkg.lxr --depth 2

            # Show tree with verbose details
            lutaml-xsd element tree gml:Point pkg.lxr --verbose
        DESC
        option :depth,
               type: :numeric,
               default: 3,
               desc: "Maximum depth to display"
        def tree(element_name, package_file)
          TreeCommand.new(element_name, package_file, options).run
        end

        desc "usage ELEMENT_NAME PACKAGE_FILE", "Show where element is used"
        long_desc <<~DESC
          Display information about where an element is referenced or used
          within the schema repository.

          Examples:
            # Show element usage
            lutaml-xsd element usage gml:Point pkg.lxr

            # Show usage in JSON format
            lutaml-xsd element usage gml:Point pkg.lxr --format json
        DESC
        def usage(element_name, package_file)
          UsageCommand.new(element_name, package_file, options).run
        end

        desc "by_namespace PACKAGE", "List elements grouped by namespace"
        long_desc <<~DESC
          Display all elements organized by namespace, showing their types and details.

          Examples:
            lutaml-xsd element by_namespace schemas.lxr
            lutaml-xsd element by_namespace schemas.lxr --namespace "http://..."
            lutaml-xsd element by_namespace schemas.lxr --format json
        DESC
        option :namespace, type: :string,
                           desc: "Filter by specific namespace URI"
        option :format, type: :string, default: "text", enum: %w[text json yaml]
        def by_namespace(package_path)
          ByNamespaceCommand.new(package_path, options).run
        end

        map "bn" => :by_namespace

        # List command implementation
        class ListCommand < BaseCommand
          def initialize(package_file, options)
            super(options)
            @package_file = package_file
          end

          def run
            repository = load_repository(@package_file)
            repository = ensure_resolved(repository)

            list_elements(repository)
          end

          private

          def list_elements(repository)
            elements = collect_elements(repository)

            format = options[:format] || "text"

            case format
            when "json", "yaml"
              output format_output(elements, format)
            else
              display_text_list(elements, repository)
            end
          end

          def collect_elements(repository)
            type_index = repository.instance_variable_get(:@type_index)
            all_types = type_index.all

            elements = all_types.select do |_key, type_info|
              type_info[:type] == :element
            end

            # Filter by namespace if specified
            if options[:namespace]
              elements = elements.select do |_key, type_info|
                type_info[:namespace] == options[:namespace]
              end
            end

            elements.values.filter_map do |type_info|
              {
                name: type_info[:definition]&.name,
                namespace: type_info[:namespace],
                type: extract_element_type(type_info[:definition]),
                schema_file: File.basename(type_info[:schema_file]),
              }
            end
          end

          def extract_element_type(element)
            return element.type if element.type

            # If element has a complex or simple type definition
            if element.complex_type
              "(inline complex type)"
            elsif element.simple_type
              "(inline simple type)"
            else
              "(untyped)"
            end
          end

          def display_text_list(elements, repository)
            require "table_tennis"

            output "Elements in Repository"
            output "=" * 80
            output ""
            output "Total Elements: #{elements.size}"

            if options[:namespace]
              namespace_registry = repository.instance_variable_get(:@namespace_registry)
              prefix = namespace_registry.get_primary_prefix(options[:namespace])
              prefix_str = prefix ? " (#{prefix})" : ""
              output "Filtered by Namespace: #{options[:namespace]}#{prefix_str}"
            end

            output ""

            # Group by namespace
            by_namespace = elements.group_by { |e| e[:namespace] }
            by_namespace.sort_by { |ns, _| ns || "" }.each do |ns, ns_elements|
              namespace_registry = repository.instance_variable_get(:@namespace_registry)
              prefix = namespace_registry.get_primary_prefix(ns)
              prefix_str = prefix ? " (#{prefix})" : ""

              output ""
              output "#{ns || '(no namespace)'}#{prefix_str} - #{ns_elements.size} elements"
              output "-" * 80

              # Build table data as array of hashes
              element_data = if verbose?
                               ns_elements.sort_by do |e|
                                 e[:name]
                               end.map do |elem|
                                 {
                                   "Name" => elem[:name],
                                   "Type" => elem[:type] || "(untyped)",
                                   "Schema File" => elem[:schema_file],
                                 }
                               end
                             else
                               ns_elements.sort_by do |e|
                                 e[:name]
                               end.map do |elem|
                                 {
                                   "Name" => elem[:name],
                                   "Type" => elem[:type] || "(untyped)",
                                 }
                               end
                             end

              element_table = TableTennis.new(element_data)
              output element_table
            end
          end
        end

        # Show command implementation
        class ShowCommand < BaseCommand
          def initialize(element_name, package_file, options)
            super(options)
            @element_name = element_name
            @package_file = package_file
          end

          def run
            repository = load_repository(@package_file)
            repository = ensure_resolved(repository)

            show_element(repository)
          end

          private

          def show_element(repository)
            result = repository.find_type(@element_name)

            unless result.resolved?
              error "Element not found: #{@element_name}"
              output ""
              output result.error_message if result.error_message
              raise CommandError
            end

            unless result.definition.is_a?(Lutaml::Xsd::Element)
              error "Type '#{@element_name}' is not an element (found: #{result.definition.class.name})"
              raise CommandError
            end

            element_info = build_element_info(result, repository)

            format = options[:format] || "text"

            case format
            when "json", "yaml"
              output format_output(element_info, format)
            else
              display_text_info(element_info, result.definition)
            end
          end

          def build_element_info(result, _repository)
            element = result.definition
            info = {
              name: element.name,
              namespace: result.namespace,
              qualified_name: result.qname,
              schema_file: File.basename(result.schema_file),
            }

            # Extract type information
            if element.type
              info[:type_ref] =
                element.type
            end

            # Extract attributes if requested
            if options[:show_attributes]
              info[:attributes] =
                extract_attributes(element)
            end

            # Extract documentation
            if element.annotation
              info[:documentation] =
                extract_documentation(element.annotation)
            end

            info
          end

          def extract_attributes(element)
            attrs = []

            # Direct attributes
            attrs.concat(Array(element.attribute)) if element.attribute.any?

            attrs.filter_map do |attr|
              {
                name: attr.name,
                type: attr.type,
                use: attr.use,
              }
            end
          end

          def extract_documentation(annotation)
            docs = annotation.documentation
            return nil unless docs

            Array(docs).filter_map do |doc|
              doc.content || doc.to_s
            end.join("\n").strip
          end

          def display_text_info(info, element)
            output "=" * 80
            output "Element: #{info[:name]}"
            output "=" * 80
            output ""
            output "Qualified Name: #{info[:qualified_name]}"
            output "Namespace: #{info[:namespace]}"
            output "Schema File: #{info[:schema_file]}"

            if info[:type_ref]
              output "Type Reference: #{info[:type_ref]}"
            elsif element.complex_type
              output "Type: (inline complex type)"
            elsif element.simple_type
              output "Type: (inline simple type)"
            end

            if info[:documentation] && !info[:documentation].empty?
              output ""
              output "Documentation:"
              info[:documentation].split("\n").each do |line|
                output "  #{line.strip}"
              end
            end

            return unless options[:show_attributes] && info[:attributes]&.any?

            output ""
            output "Attributes:"
            info[:attributes].each do |attr|
              use_str = attr[:use] ? " (#{attr[:use]})" : ""
              output "  - #{attr[:name]}: #{attr[:type]}#{use_str}"
            end
          end
        end

        # Tree command implementation
        class TreeCommand < BaseCommand
          def initialize(element_name, package_file, options)
            super(options)
            @element_name = element_name
            @package_file = package_file
            @max_depth = options[:depth] || 3
          end

          def run
            repository = load_repository(@package_file)
            repository = ensure_resolved(repository)

            display_element_tree(repository)
          end

          private

          def display_element_tree(repository)
            result = repository.find_type(@element_name)

            unless result.resolved?
              error "Element not found: #{@element_name}"
              raise CommandError
            end

            unless result.definition.is_a?(Lutaml::Xsd::Element)
              error "Type '#{@element_name}' is not an element"
              raise CommandError
            end

            output "Element Structure: #{result.qname}"
            output "=" * 80
            output ""

            display_element_node(result.definition, "", true, 0, repository)
          end

          def display_element_node(element, indent, is_last, depth, repository)
            return if depth > @max_depth

            connector = is_last ? "└── " : "├── "
            name = element.name || "(unnamed)"
            type_info = get_type_info(element)

            output "#{indent}#{connector}#{name}#{type_info}"

            # Don't recurse further if we're at max depth
            return if depth >= @max_depth

            child_indent = indent + (is_last ? "    " : "│   ")

            # Display child elements from complex type
            if element.complex_type
              display_complex_type_children(element.complex_type, child_indent,
                                            depth, repository)
            elsif element.type
              # Try to resolve the type reference
              type_result = repository.find_type(element.type)
              if type_result.resolved? && type_result.definition.sequence
                display_sequence_children(type_result.definition.sequence, child_indent, depth,
                                          repository)
              end
            end
          end

          def get_type_info(element)
            if element.type
              " : #{element.type}"
            elsif element.complex_type
              " : (complex type)"
            elsif element.simple_type
              " : (simple type)"
            else
              ""
            end
          end

          def display_complex_type_children(complex_type, indent, depth,
repository)
            # Display sequence elements
            if complex_type.sequence
              display_sequence_children(complex_type.sequence, indent, depth,
                                        repository)
            end

            # Display choice elements
            return unless complex_type.choice

            display_choice_children(complex_type.choice, indent, depth,
                                    repository)
          end

          def display_sequence_children(sequence, indent, depth, repository)
            elements = Array(sequence.element).compact
            return if elements.empty?

            elements.each_with_index do |elem, idx|
              is_last = idx == elements.size - 1
              display_element_node(elem, indent, is_last, depth + 1, repository)
            end
          end

          def display_choice_children(choice, indent, depth, repository)
            elements = Array(choice.element).compact
            return if elements.empty?

            output "#{indent}└── (choice)"
            choice_indent = "#{indent}    "

            elements.each_with_index do |elem, idx|
              is_last = idx == elements.size - 1
              display_element_node(elem, choice_indent, is_last, depth + 1,
                                   repository)
            end
          end
        end

        # Usage command implementation
        class UsageCommand < BaseCommand
          def initialize(element_name, package_file, options)
            super(options)
            @element_name = element_name
            @package_file = package_file
          end

          def run
            repository = load_repository(@package_file)
            repository = ensure_resolved(repository)

            show_element_usage(repository)
          end

          private

          def show_element_usage(repository)
            result = repository.find_type(@element_name)

            unless result.resolved?
              error "Element not found: #{@element_name}"
              raise CommandError
            end

            output "Element Usage: #{result.qname}"
            output "=" * 80
            output ""

            output "Namespace: #{result.namespace}"
            output "Schema File: #{File.basename(result.schema_file)}"
            output ""

            output "Note: Full usage tracking is not yet implemented."
            output "This feature will show which types reference this element in future versions."
          end
        end

        # ByNamespace command implementation
        class ByNamespaceCommand < BaseCommand
          def initialize(package_path, options)
            super(options)
            @package_path = package_path
          end

          def run
            repository = load_repository(@package_path)
            repository = ensure_resolved(repository)

            elements = repository.elements_by_namespace(
              namespace_uri: options[:namespace],
            )

            case options[:format]
            when "json", "yaml"
              output format_output(elements, options[:format])
            else
              display_text_output(elements, repository)
            end
          end

          private

          def display_text_output(elements, repository)
            require "table_tennis"

            elements.each do |namespace_uri, elems|
              prefix = repository.namespace_to_prefix(namespace_uri) || "(no prefix)"

              output ""
              output "=" * 80
              output "Namespace: #{prefix}"
              output "URI: #{namespace_uri}"
              output "Elements: #{elems.size}"
              output "=" * 80
              output ""

              # Create table for elements
              elems_data = elems.map do |elem|
                {
                  "Element" => elem[:qualified_name],
                  "Type" => elem[:type],
                  "Cardinality" => "[#{elem[:min_occurs]}..#{elem[:max_occurs] == 'unbounded' ? '*' : elem[:max_occurs]}]",
                  "Documentation" => elem[:documentation],
                }
              end

              table = TableTennis.new(elems_data)

              output table
            end
          end
        end
      end
    end
  end
end
