# frozen_string_literal: true

require_relative "../output_formatter"
require_relative "shared_helpers"

module Lutaml
  module Cli
    module Uml
      # TreeCommand shows hierarchical tree view
      class TreeCommand
        include SharedHelpers

        attr_reader :options

        def initialize(options = {})
          @options = options.transform_keys(&:to_sym)
        end

        def self.add_options_to(thor_class, _method_name)
          thor_class.long_desc <<-DESC
          Display a tree view of the package hierarchy.

          Examples:
            lutaml uml tree model.lur                     # Full tree
            lutaml uml tree model.lur ModelRoot::Core     # Subtree
            lutaml uml tree model.lur --depth 2           # Limited depth
          DESC

          thor_class.option :depth, aliases: "-d", type: :numeric,
                                    desc: "Maximum depth to display"
          thor_class.option :show_counts, type: :boolean, default: true,
                                          desc: "Show class and diagram counts"
          thor_class.option :format, type: :string, default: "text",
                                     desc: "Output format (text|yaml|json)"
          thor_class.option :lazy, type: :boolean, default: false,
                                   desc: "Use lazy loading"
        end

        def run(lur_path, path = nil)
          unless File.exist?(lur_path)
            puts OutputFormatter.error("Package file not found: #{lur_path}")
            raise Thor::Error, "Package file not found: #{lur_path}"
          end

          path = normalize_path(path)
          repo = load_repository(lur_path, lazy: options[:lazy])
          tree_data = repo.package_tree(path, max_depth: options[:depth])

          unless tree_data
            puts OutputFormatter.error("Package not found: #{path}")
            raise Thor::Error, "Package not found: #{path}"
          end

          if options[:format] == "text"
            puts display_tree_without_root(tree_data,
                                           show_counts: options[:show_counts])
          else
            puts OutputFormatter.format(tree_data, format: options[:format])
          end
        end

        private

        def display_tree_without_root(tree_data, show_counts: true)
          name = tree_data.is_a?(Hash) ? (tree_data["name"] || tree_data[:name]) : nil

          if name == "ModelRoot"
            children = tree_data["children"] || tree_data[:children]
            if children.is_a?(Array) && !children.empty?
              children.map do |child|
                OutputFormatter.format_tree(child, show_counts: show_counts)
              end.join("\n")
            else
              "(empty repository)"
            end
          else
            OutputFormatter.format_tree(tree_data, show_counts: show_counts)
          end
        end
      end
    end
  end
end
