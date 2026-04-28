# frozen_string_literal: true

module Lutaml
  module UmlRepository
    module Exporters
      module Markdown
        class IndexPageBuilder
          def initialize(repository, options, link_resolver)
            @repository = repository
            @options = options
            @link_resolver = link_resolver
          end

          def build
            title = @options.fetch(:title, "UML Model Documentation")
            stats = @repository.statistics

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

          private

          def build_package_tree_markdown
            root_path = @options[:package] || "ModelRoot"
            tree = @repository.package_tree(root_path)
            return "No packages found." unless tree

            build_tree_node(tree, 0)
          end

          def build_tree_node(node, depth)
            indent = "  " * depth
            path = node[:path]
            link = @link_resolver.package_link(path)
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
        end
      end
    end
  end
end
