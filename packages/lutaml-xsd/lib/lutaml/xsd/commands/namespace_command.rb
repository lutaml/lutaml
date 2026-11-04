# frozen_string_literal: true

require "thor"
require_relative "base_command"

module Lutaml
  module Xsd
    module Commands
      # Namespace exploration commands
      # Handles listing, showing, and visualizing namespace hierarchies
      class NamespaceCommand < Thor
        # Command aliases
        map "ls" => :list
        map "s" => :show
        map "t" => :tree

        class_option :verbose,
                     type: :boolean,
                     default: false,
                     desc: "Enable verbose output"

        desc "list PACKAGE_FILE", "List all namespaces in the repository"
        long_desc <<~DESC
          List all namespaces in the schema repository with their prefixes and type counts.

          Examples:
            # List all namespaces
            lutaml-xsd namespace list pkg.lxr

            # List namespaces in JSON format
            lutaml-xsd namespace list pkg.lxr --format json

            # List namespaces with type counts
            lutaml-xsd namespace list pkg.lxr --show-counts
        DESC
        option :format,
               type: :string,
               default: "text",
               enum: %w[text json yaml],
               desc: "Output format"
        option :show_counts,
               type: :boolean,
               default: true,
               desc: "Show type counts for each namespace"
        def list(package_file)
          ListCommand.new(package_file, options).run
        end

        desc "show NAMESPACE_URI PACKAGE_FILE",
             "Show details about a specific namespace"
        long_desc <<~DESC
          Display detailed information about a specific namespace including its prefix,
          type counts, and optionally list all types in the namespace.

          Examples:
            # Show namespace details
            lutaml-xsd namespace show http://www.opengis.net/gml/3.2 pkg.lxr

            # Show namespace with type listing
            lutaml-xsd namespace show http://www.opengis.net/gml/3.2 pkg.lxr --show-types

            # Show namespace in JSON format
            lutaml-xsd namespace show http://www.opengis.net/gml/3.2 pkg.lxr --format json
        DESC
        option :format,
               type: :string,
               default: "text",
               enum: %w[text json yaml],
               desc: "Output format"
        option :show_types,
               type: :boolean,
               default: true,
               desc: "Show types in the namespace"
        def show(namespace_uri, package_file)
          ShowCommand.new(namespace_uri, package_file, options).run
        end

        desc "tree PACKAGE_FILE", "Show namespace hierarchy and relationships"
        long_desc <<~DESC
          Display the namespace hierarchy showing import relationships
          between namespaces.

          Examples:
            # Show namespace tree
            lutaml-xsd namespace tree pkg.lxr

            # Limit tree depth
            lutaml-xsd namespace tree pkg.lxr --depth 2

            # Show tree in verbose mode
            lutaml-xsd namespace tree pkg.lxr --verbose
        DESC
        option :depth,
               type: :numeric,
               default: 3,
               desc: "Maximum depth to display"
        def tree(package_file)
          TreeCommand.new(package_file, options).run
        end

        desc "prefixes PACKAGE_FILE", "List namespace prefixes with details"
        long_desc <<~DESC
          Display detailed information about all namespace prefixes in the repository,
          including their URIs, schema locations, and type counts.

          Examples:
            # List all prefixes in text format
            lutaml-xsd namespace prefixes pkg.lxr

            # List prefixes in JSON format
            lutaml-xsd namespace prefixes pkg.lxr --format json

            # List prefixes in YAML format
            lutaml-xsd namespace prefixes pkg.lxr --format yaml
        DESC
        option :format,
               type: :string,
               default: "text",
               enum: %w[text json yaml],
               desc: "Output format"
        def prefixes(package_file)
          PrefixesCommand.new(package_file, options).run
        end

        desc "remap PACKAGE_FILE", "Remap namespace prefixes"
        long_desc <<~DESC
          Create a new package with remapped namespace prefixes. This allows you to
          change prefix names while preserving all namespace URIs and type definitions.

          Examples:
            # Remap a single prefix
            lutaml-xsd namespace remap pkg.lxr --change unitsml=units -o remapped.lxr

            # Remap multiple prefixes
            lutaml-xsd namespace remap pkg.lxr --change gml=gml32 --change xlink=xl -o remapped.lxr

            # Swap two prefixes
            lutaml-xsd namespace remap pkg.lxr --change a=b --change b=a -o swapped.lxr
        DESC
        option :change,
               type: :array,
               required: true,
               desc: "Prefix mappings in format old=new"
        option :output,
               type: :string,
               aliases: "-o",
               required: true,
               desc: "Output package path"
        def remap(package_file)
          RemapCommand.new(package_file, options).run
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

            list_namespaces(repository)
          end

          private

          def list_namespaces(repository)
            namespaces = repository.all_namespaces
            namespace_data = build_namespace_data(repository, namespaces)

            format = options[:format] || "text"

            case format
            when "json", "yaml"
              output format_output(namespace_data, format)
            else
              display_text_list(namespace_data)
            end
          end

          def build_namespace_data(repository, namespaces)
            namespaces.map do |uri|
              data = {
                uri: uri,
                prefix: repository.namespace_to_prefix(uri),
              }

              if options[:show_counts]
                types = repository.types_in_namespace(uri)
                data[:type_count] = types.size
                data[:types_by_category] = count_types_by_category(types)
              end

              data
            end
          end

          def count_types_by_category(types)
            counts = Hash.new(0)
            types.each do |type_info|
              counts[type_info[:type]] += 1
            end
            counts
          end

          def display_text_list(namespace_data)
            require "table_tennis"

            output "Namespaces in Repository"
            output "=" * 80
            output ""

            # Build table data as array of hashes for proper headers
            table_data = namespace_data.map do |ns|
              {
                "Prefix" => ns[:prefix] || "(no prefix)",
                "Namespace URI" => ns[:uri],
                "Types" => ns[:type_count] || 0,
              }
            end

            table = TableTennis.new(table_data)
            output table
            output ""
            output "Total: #{namespace_data.size} namespaces"

            # In verbose mode, show type category breakdown
            return unless verbose?

            namespace_data.each do |ns|
              next unless ns[:types_by_category]&.any?

              output ""
              prefix_str = ns[:prefix] ? " (#{ns[:prefix]})" : ""
              output "#{ns[:uri]}#{prefix_str} - Type Categories:"

              category_data = ns[:types_by_category].sort.map do |category, count|
                { "Category" => category.to_s, "Count" => count }
              end

              category_table = TableTennis.new(category_data)
              output category_table
            end
          end
        end

        # Show command implementation
        class ShowCommand < BaseCommand
          def initialize(namespace_uri, package_file, options)
            super(options)
            @namespace_uri = namespace_uri
            @package_file = package_file
          end

          def run
            repository = load_repository(@package_file)
            repository = ensure_resolved(repository)

            show_namespace(repository)
          end

          private

          def show_namespace(repository)
            unless repository.all_namespaces.include?(@namespace_uri)
              error "Namespace not found: #{@namespace_uri}"
              suggest_similar_namespaces(repository)
              raise CommandError
            end

            namespace_info = build_namespace_info(repository)
            format = options[:format] || "text"

            case format
            when "json", "yaml"
              output format_output(namespace_info, format)
            else
              display_text_info(namespace_info)
            end
          end

          def build_namespace_info(repository)
            types = repository.types_in_namespace(@namespace_uri)
            types_by_category = Hash.new(0)
            types.each { |type_info| types_by_category[type_info[:type]] += 1 }

            info = {
              uri: @namespace_uri,
              prefix: repository.namespace_to_prefix(@namespace_uri),
              total_types: types.size,
              types_by_category: types_by_category,
            }

            if options[:show_types]
              info[:types] = types.filter_map do |type_info|
                {
                  name: type_info[:definition]&.name,
                  category: type_info[:type],
                  schema_file: File.basename(type_info[:schema_file]),
                }
              end
            end

            info
          end

          def display_text_info(info)
            require "table_tennis"

            output "=" * 80
            output "Namespace: #{info[:uri]}"
            output "=" * 80
            output ""
            output "Prefix: #{info[:prefix] || '(none)'}"
            output "Total Types: #{info[:total_types]}"
            output ""
            output "Types by Category:"

            # Build category table data as hashes
            category_data = info[:types_by_category].sort.map do |category, count|
              { "Category" => category.to_s, "Count" => count }
            end

            category_table = TableTennis.new(category_data)
            output category_table

            return unless options[:show_types] && info[:types]

            output ""
            output "Types in Namespace:"
            output "-" * 80

            # Group types by category and display in tables
            info[:types].group_by do |t|
              t[:category]
            end.sort.each do |category, types|
              output ""
              output "#{category}:"

              type_data = if verbose?
                            types.sort_by { |t| t[:name] }.map do |type|
                              { "Name" => type[:name],
                                "Schema File" => type[:schema_file] }
                            end
                          else
                            types.sort_by { |t| t[:name] }.map do |type|
                              { "Name" => type[:name] }
                            end
                          end

              type_table = TableTennis.new(type_data)
              output type_table
            end
          end

          def suggest_similar_namespaces(repository)
            namespaces = repository.all_namespaces
            similar = namespaces.select do |uri|
              uri.downcase.include?(@namespace_uri.downcase) ||
                @namespace_uri.downcase.include?(uri.downcase)
            end

            return if similar.empty?

            output ""
            output "Similar namespaces found:"
            similar.each { |uri| output "  - #{uri}" }
          end
        end

        # Tree command implementation
        class TreeCommand < BaseCommand
          def initialize(package_file, options)
            super(options)
            @package_file = package_file
          end

          def run
            repository = load_repository(@package_file)
            repository = ensure_resolved(repository)

            display_namespace_tree(repository)
          end

          private

          def display_namespace_tree(repository)
            output "Namespace Hierarchy"
            output "=" * 80
            output ""

            namespaces = repository.all_namespaces
            namespace_data = build_tree_data(repository, namespaces)

            namespace_data.each_with_index do |ns, idx|
              is_last = idx == namespace_data.size - 1
              display_namespace_node(ns, "", is_last)
            end
          end

          def build_tree_data(repository, namespaces)
            tree_data = namespaces.map do |uri|
              types = repository.types_in_namespace(uri)
              {
                uri: uri,
                prefix: repository.namespace_to_prefix(uri),
                type_count: types.size,
                types_by_category: count_types_by_category(types),
              }
            end
            tree_data.sort_by do |namespace|
              namespace[:prefix] || namespace[:uri]
            end
          end

          def count_types_by_category(types)
            counts = Hash.new(0)
            types.each { |type_info| counts[type_info[:type]] += 1 }
            counts
          end

          def display_namespace_node(namespace_data, indent, is_last)
            connector = is_last ? "└── " : "├── "
            prefix_str = namespace_data[:prefix] ? " (#{namespace_data[:prefix]})" : ""

            output "#{indent}#{connector}#{namespace_data[:uri]}#{prefix_str}"

            child_indent = indent + (is_last ? "    " : "│   ")

            # Show type count
            output "#{child_indent}└── #{namespace_data[:type_count]} types"

            return unless verbose? && namespace_data[:types_by_category].any?

            # Show category breakdown in verbose mode
            categories = namespace_data[:types_by_category].sort
            categories.each_with_index do |(category, count), idx|
              cat_is_last = idx == categories.size - 1
              cat_connector = cat_is_last ? "    └── " : "    ├── "
              output "#{child_indent}#{cat_connector}#{category}: #{count}"
            end
          end
        end

        # Prefixes command implementation
        class PrefixesCommand < BaseCommand
          def initialize(package_file, options)
            super(options)
            @package_file = package_file
          end

          def run
            repository = load_repository(@package_file)
            repository = ensure_resolved(repository)

            display_prefixes(repository)
          end

          private

          def display_prefixes(repository)
            prefix_details = repository.namespace_prefix_details
            format = options[:format] || "text"

            case format
            when "json", "yaml"
              data = prefix_details.map(&:to_h)
              output format_output(data, format)
            else
              display_text_prefixes(prefix_details)
            end
          end

          def display_text_prefixes(prefix_details)
            require "table_tennis"

            output "Namespace Prefix Details"
            output "=" * 80
            output ""

            # Build table data
            table_data = prefix_details.map do |info|
              {
                "Prefix" => info.prefix,
                "Namespace URI" => info.uri,
                "Types" => info.type_count,
                "Location" => info.package_location ? File.basename(info.package_location) : "N/A",
              }
            end

            table = TableTennis.new(table_data)
            output table
            output ""
            output "Total: #{prefix_details.size} namespace prefixes"

            # Show detailed type breakdown in verbose mode
            return unless verbose?

            prefix_details.each do |info|
              next unless info.types_by_category.any?

              output ""
              output "#{info.prefix} (#{info.uri}) - Type Categories:"

              category_data = info.types_by_category.sort.map do |category, count|
                { "Category" => category.to_s, "Count" => count }
              end

              category_table = TableTennis.new(category_data)
              output category_table
            end
          end
        end

        # Remap command implementation
        class RemapCommand < BaseCommand
          def initialize(package_file, options)
            super(options)
            @package_file = package_file
          end

          def run
            repository = load_repository(@package_file)
            repository = ensure_resolved(repository)

            # Parse change mappings
            changes = parse_changes(options[:change])

            # Perform remapping
            remapped_repository = remap_prefixes(repository, changes)

            # Save to output file
            save_remapped_package(remapped_repository, options[:output])
          end

          private

          def parse_changes(change_args)
            changes = {}
            change_args.each do |arg|
              unless arg.include?("=")
                error "Invalid change format: #{arg}. Expected format: old=new"
                raise CommandError
              end

              old_prefix, new_prefix = arg.split("=", 2)
              changes[old_prefix] = new_prefix
            end
            changes
          end

          def remap_prefixes(repository, changes)
            output "Remapping namespace prefixes..." if verbose?

            changes.each do |old_prefix, new_prefix|
              output "  #{old_prefix} -> #{new_prefix}" if verbose?
            end

            begin
              repository.remap_namespace_prefixes(changes)
            rescue ArgumentError => e
              error "Remapping failed: #{e.message}"
              raise CommandError
            end
          end

          def save_remapped_package(repository, output_path)
            output "Creating remapped package: #{output_path}" if verbose?

            repository.to_package(
              output_path,
              xsd_mode: :include_all,
              resolution_mode: :resolved,
              serialization_format: :marshal,
            )

            output "✓ Remapped package created successfully: #{output_path}"
          end
        end
      end
    end
  end
end
