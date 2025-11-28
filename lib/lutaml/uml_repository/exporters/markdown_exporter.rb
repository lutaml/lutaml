# frozen_string_literal: true

require "fileutils"
require_relative "base_exporter"

module Lutaml
  module UmlRepository
    module Exporters
      # Export UML repository to Markdown documentation.
      #
      # Generates a complete documentation site in Markdown format with:
      # - Index page with package tree
      # - Package pages with class listings
      # - Class pages with attributes and associations
      # - Diagram references
      #
      # @example Basic export
      #   exporter = MarkdownExporter.new(repository)
      #   exporter.export("docs/")
      #
      # @example Export specific package
      #   exporter.export("docs/", package: "ModelRoot::i-UR::urf")
      class MarkdownExporter < BaseExporter
        # Export repository to Markdown documentation.
        #
        # @param output_path [String] Path to the output directory
        # @param options [Hash] Export options
        # @option options [String] :package Filter by package path
        # @option options [Boolean] :recursive (true) Include nested packages
        # @option options [String] :title ("UML Model Documentation") Site title
        # @return [void]
        def export(output_path, options = {})
          @output_dir = output_path
          @options = options

          create_directory_structure
          generate_index_page
          generate_package_pages
          generate_class_pages
        end

        private

        attr_reader :output_dir, :options

        # Create the directory structure for documentation.
        #
        # @return [void]
        def create_directory_structure
          FileUtils.mkdir_p(output_dir)
          FileUtils.mkdir_p(File.join(output_dir, "packages"))
          FileUtils.mkdir_p(File.join(output_dir, "classes"))
        end

        # Generate the index page.
        #
        # @return [void]
        def generate_index_page
          content = build_index_content
          File.write(File.join(output_dir, "index.md"), content)
        end

        # Build index page content.
        #
        # @return [String] The index page content
        def build_index_content
          title = options.fetch(:title, "UML Model Documentation")
          stats = repository.statistics

          <<~MARKDOWN
            # #{title}

            ## Overview

            This documentation provides comprehensive information about the UML model.

            ## Statistics

            - **Total Packages**: #{stats&.dig(:total_packages) || 0}
            - **Total Classes**: #{stats&.dig(:total_classes) || 0}
            - **Total Associations**: #{stats&.dig(:total_associations) || 0}
            - **Total Diagrams**: #{stats&.dig(:total_diagrams) || 0}

            ## Package Structure

            #{build_package_tree_markdown}

            ## Navigation

            - [Packages](packages/)
            - [Classes](classes/)
          MARKDOWN
        end

        # Build package tree in Markdown format.
        #
        # @return [String] The package tree markdown
        def build_package_tree_markdown
          root_path = options[:package] || "ModelRoot"
          tree = repository.package_tree(root_path)
          return "No packages found." unless tree

          build_tree_node(tree, 0)
        end

        # Build a tree node recursively.
        #
        # @param node [Hash] The tree node
        # @param depth [Integer] Current depth
        # @return [String] Markdown representation
        def build_tree_node(node, depth)
          indent = "  " * depth
          path = node[:path]
          link = package_link(path)
          result = "#{indent}- [#{node[:name]}](#{link})"
          result += " (#{node[:classes_count]} classes)" if node[:classes_count].positive?
          result += "\n"

          if node[:children]&.any?
            node[:children].each do |child|
              result += build_tree_node(child, depth + 1)
            end
          end

          result
        end

        # Generate package pages.
        #
        # @return [void]
        def generate_package_pages
          root_path = options[:package] || "ModelRoot"
          packages = repository.list_packages(
            root_path,
            recursive: options.fetch(:recursive, true),
          )

          packages.each do |package|
            generate_package_page(package)
          end
        end

        # Generate a single package page.
        #
        # @param package [Lutaml::Uml::Package, Lutaml::Uml::Document]
        #   The package object
        # @return [void]
        def generate_package_page(package)
          path = package_path(package)
          content = build_package_content(package, path)
          filename = sanitize_filename("#{path}.md")
          File.write(File.join(output_dir, "packages", filename), content)
        end

        # Build package page content.
        #
        # @param package [Object] The package object
        # @param path [String] The package path
        # @return [String] The package page content
        def build_package_content(package, path)
          classes = repository.classes_in_package(path, recursive: false)
          sub_packages = package.packages || []

          <<~MARKDOWN
            # Package: #{package.name}

            **Qualified Path**: `#{path}`

            ## Description

            #{package.definition || 'No description available.'}

            ## Statistics

            - **Direct Classes**: #{classes.size}
            - **Sub-packages**: #{sub_packages.size}

            #{build_sub_packages_section(sub_packages)}

            #{build_classes_section(classes)}

            #{build_diagrams_section(path)}

            ---

            [Back to Index](../index.md)
          MARKDOWN
        end

        # Build sub-packages section.
        #
        # @param packages [Array] Array of package objects
        # @return [String] Markdown content
        def build_sub_packages_section(packages)
          return "" if packages.empty?

          content = "## Sub-packages\n\n"
          packages.each do |pkg|
            pkg_path = package_path(pkg)
            link = package_link(pkg_path)
            content += "- [#{pkg.name}](#{link})\n"
          end
          "#{content}\n"
        end

        # Build classes section.
        #
        # @param classes [Array] Array of class objects
        # @return [String] Markdown content
        def build_classes_section(classes)
          return "## Classes\n\nNo classes in this package.\n" if classes.empty?

          content = "## Classes\n\n"
          content += "| Name | Type | Stereotypes | Attributes | Associations |\n"
          content += "|------|------|-------------|------------|---------------|\n"

          classes.sort_by(&:name).each do |klass|
            content += format_class_table_row(klass)
          end

          "#{content}\n"
        end

        # Format a class as a table row.
        #
        # @param klass [Object] The class object
        # @return [String] Markdown table row
        def format_class_table_row(klass)
          qname = qualified_name(klass)
          link = class_link(qname)
          type = klass.class.name.split("::").last
          stereotypes = format_stereotypes(klass.stereotype)
          attrs_count = klass.attributes&.size || 0
          assocs_count = count_associations(klass)

          "| [#{klass.name}](#{link}) | #{type} | #{stereotypes} | #{attrs_count} | #{assocs_count} |\n"
        end

        # Format stereotypes (can be string or array).
        #
        # @param stereotype [String, Array, nil] The stereotype(s)
        # @return [String] Formatted stereotype string
        def format_stereotypes(stereotype)
          return "" unless stereotype

          case stereotype
          when Array
            stereotype.join(", ")
          when String
            stereotype
          else
            ""
          end
        end

        # Build diagrams section.
        #
        # @param package_path [String] The package path
        # @return [String] Markdown content
        def build_diagrams_section(package_path)
          diagrams = repository.diagrams_in_package(package_path)
          return "" if diagrams.empty?

          content = "## Diagrams\n\n"
          diagrams.each do |diagram|
            content += "- **#{diagram.name}** (#{diagram.diagram_type})\n"
          end
          "#{content}\n"
        rescue StandardError
          ""
        end

        # Generate class pages.
        #
        # @return [void]
        def generate_class_pages
          classes = if options[:package]
                      repository.classes_in_package(
                        options[:package],
                        recursive: options.fetch(:recursive, true),
                      )
                    else
                      indexes&.dig(:classes)&.values || []
                    end

          classes.each do |klass|
            generate_class_page(klass)
          end
        end

        # Generate a single class page.
        #
        # @param klass [Object] The class object
        # @return [void]
        def generate_class_page(klass)
          qname = qualified_name(klass)
          content = build_class_content(klass, qname)
          filename = sanitize_filename("#{qname}.md")
          File.write(File.join(output_dir, "classes", filename), content)
        end

        # Build class page content.
        #
        # @param klass [Object] The class object
        # @param qname [String] The qualified name
        # @return [String] The class page content
        def build_class_content(klass, qname)
          type = klass.class.name.split("::").last
          pkg_path = extract_package_path(qname)

          <<~MARKDOWN
            # #{type}: #{klass.name}

            **Qualified Name**: `#{qname}`

            **Package**: [#{pkg_path}](#{package_link(pkg_path)})

            #{build_stereotypes_section(klass)}

            #{build_definition_section(klass)}

            #{build_inheritance_section(klass)}

            #{build_attributes_section(klass)}

            #{build_operations_section(klass)}

            #{build_associations_section(klass)}

            #{build_enum_literals_section(klass)}

            ---

            [Back to Package](#{package_link(pkg_path)}) | [Back to Index](../index.md)
          MARKDOWN
        end

        # Build stereotypes section.
        #
        # @param klass [Object] The class object
        # @return [String] Markdown content
        def build_stereotypes_section(klass)
          stereotypes_array = normalize_stereotypes(klass.stereotype)
          return "" if stereotypes_array.empty?

          "**Stereotypes**: #{stereotypes_array.map do |s|
            "`#{s}`"
          end.join(', ')}\n\n"
        end

        # Normalize stereotypes to array format.
        #
        # @param stereotype [String, Array, nil] The stereotype(s)
        # @return [Array] Array of stereotypes
        def normalize_stereotypes(stereotype)
          return [] unless stereotype

          case stereotype
          when Array
            stereotype
          when String
            [stereotype]
          else
            []
          end
        end

        # Build definition section.
        #
        # @param klass [Object] The class object
        # @return [String] Markdown content
        def build_definition_section(klass)
          return "" unless klass.respond_to?(:definition) && klass.definition

          "## Description\n\n#{klass.definition}\n\n"
        end

        # Build inheritance section.
        #
        # @param klass [Object] The class object
        # @return [String] Markdown content
        def build_inheritance_section(klass)
          parent = repository.supertype_of(klass)
          children = repository.subtypes_of(klass)

          return "" if parent.nil? && children.empty?

          content = "## Inheritance\n\n"

          if parent
            parent_qname = qualified_name(parent)
            content += "**Extends**: [#{parent.name}](#{class_link(parent_qname)})\n\n"
          end

          if children.any?
            content += "**Extended by**:\n\n"
            children.each do |child|
              child_qname = qualified_name(child)
              content += "- [#{child.name}](#{class_link(child_qname)})\n"
            end
            content += "\n"
          end

          content
        rescue StandardError
          ""
        end

        # Build attributes section.
        #
        # @param klass [Object] The class object
        # @return [String] Markdown content
        def build_attributes_section(klass)
          return "" unless klass.attributes&.any?

          content = "## Attributes\n\n"
          content += "| Name | Type | Visibility | Cardinality |\n"
          content += "|------|------|------------|-------------|\n"

          klass.attributes.each do |attr|
            visibility = attr.visibility || ""
            cardinality = format_cardinality(attr.cardinality)
            content += "| #{attr.name} | `#{attr.type}` | #{visibility} | #{cardinality} |\n"
          end

          "#{content}\n"
        end

        # Build operations section.
        #
        # @param klass [Object] The class object
        # @return [String] Markdown content
        def build_operations_section(klass)
          return "" unless klass.respond_to?(:operations) && klass.operations&.any?

          content = "## Operations\n\n"
          content += "| Name | Return Type | Visibility |\n"
          content += "|------|-------------|------------|\n"

          klass.operations.each do |op|
            visibility = op.visibility || ""
            return_type = op.return_type || "void"
            content += "| #{op.name} | `#{return_type}` | #{visibility} |\n"
          end

          "#{content}\n"
        end

        # Build associations section.
        #
        # @param klass [Object] The class object
        # @return [String] Markdown content
        def build_associations_section(klass)
          associations = repository.associations_of(klass)
          return "" if associations.empty?

          content = "## Associations\n\n"
          content += "| Name | Target Class | Cardinality | Navigable |\n"
          content += "|------|--------------|-------------|----------|\n"

          associations.each do |assoc|
            content += format_association_row(assoc, klass)
          end

          "#{content}\n"
        rescue StandardError
          ""
        end

        # Format association as table row.
        #
        # @param association [Object] The association object
        # @param klass [Object] The source class
        # @return [String] Markdown table row
        def format_association_row(association, klass)
          source_end = association.member_end&.first
          target_end = association.member_end&.last

          # Determine which end is the target
          end_obj = if source_end&.type&.xmi_id == klass.xmi_id
                      target_end
                    else
                      source_end
                    end

          return "" unless end_obj&.type

          target_qname = qualified_name(end_obj.type)
          name = association.name || end_obj.name || ""
          cardinality = format_cardinality(end_obj.cardinality)
          navigable = end_obj.navigable? ? "Yes" : "No"

          "| #{name} | [#{end_obj.type.name}](#{class_link(target_qname)}) | #{cardinality} | #{navigable} |\n"
        end

        # Build enum literals section.
        #
        # @param klass [Object] The class object
        # @return [String] Markdown content
        def build_enum_literals_section(klass)
          return "" unless klass.is_a?(Lutaml::Uml::Enum) && klass.owned_literal&.any?

          content = "## Literals\n\n"
          klass.owned_literal.each do |literal|
            content += "- `#{literal.name}`"
            content += ": #{literal.definition}" if literal.definition
            content += "\n"
          end

          "#{content}\n"
        end

        # Format cardinality.
        #
        # @param cardinality [Lutaml::Uml::Cardinality, nil] The cardinality
        # @return [String] Formatted cardinality
        def format_cardinality(cardinality)
          return "" unless cardinality

          min = cardinality.min || "0"
          max = cardinality.max || "*"
          "#{min}..#{max}"
        end

        # Get package path.
        #
        # @param package [Object] The package object
        # @return [String] The package path
        def package_path(package)
          indexes&.dig(:package_to_path, package.xmi_id) || package.name
        end

        # Get qualified name.
        #
        # @param klass [Object] The class object
        # @return [String] The qualified name
        def qualified_name(klass)
          indexes&.dig(:class_to_qname, klass.xmi_id) || klass.name
        end

        # Extract package path from qualified name.
        #
        # @param qname [String] The qualified name
        # @return [String] The package path
        def extract_package_path(qname)
          parts = qname.split("::")
          parts.size > 1 ? parts[0..-2].join("::") : "ModelRoot"
        end

        # Count associations involving a class.
        #
        # @param klass [Object] The class object
        # @return [Integer] Count of associations
        def count_associations(klass)
          repository.associations_of(klass).size
        rescue StandardError
          0
        end

        # Generate package link.
        #
        # @param path [String] The package path
        # @return [String] Relative link
        def package_link(path)
          "../packages/#{sanitize_filename(path)}.md"
        end

        # Generate class link.
        #
        # @param qname [String] The qualified name
        # @return [String] Relative link
        def class_link(qname)
          "../classes/#{sanitize_filename(qname)}.md"
        end

        # Sanitize filename for filesystem compatibility.
        #
        # @param name [String] The filename
        # @return [String] Sanitized filename
        def sanitize_filename(name)
          name.gsub("::", "_").gsub(/[^a-zA-Z0-9_\-.]/, "_")
        end
      end
    end
  end
end
