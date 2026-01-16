# frozen_string_literal: true

require_relative "../output_formatter"
require_relative "shared_helpers"

module Lutaml
  module Cli
    module Uml
      # LsCommand lists elements in repository
      class LsCommand
        include SharedHelpers

        attr_reader :options

        def initialize(options = {})
          @options = options.transform_keys(&:to_sym)
        end

        def self.add_options_to(thor_class, _method_name) # rubocop:disable Metrics/MethodLength
          thor_class.long_desc <<-DESC
          List elements at the specified path in the repository.

          Examples:
            lutaml uml ls model.lur                    # List top-level packages
            lutaml uml ls model.lur ModelRoot::Core    # List in Core package
            lutaml uml ls model.lur --type classes     # List all classes
            lutaml uml ls model.lur --type diagrams    # List all diagrams
          DESC

          thor_class.option :type, type: :string, default: "packages",
                                   desc: "Element type " \
                                         "(packages|classes|diagrams|all)"
          thor_class.option :format, type: :string, default: "text",
                                     desc: "Output format " \
                                           "(text|table|yaml|json)"
          thor_class.option :filter, type: :string, desc: "Filter pattern"
          thor_class.option :recursive, aliases: "-r", type: :boolean,
                                        default: false,
                                        desc: "Include nested elements"
          thor_class.option :lazy, type: :boolean, default: false,
                                   desc: "Use lazy loading"
        end

        def run(lur_path, path = nil) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          path = normalize_path(path)
          repo = load_repository(lur_path, lazy: options[:lazy])

          elements = case options[:type].downcase
                     when "packages"
                       repo.list_packages(path, recursive: options[:recursive])
                     when "classes"
                       if path
                         repo.classes_in_package(path,
                                                 recursive: options[:recursive])
                       else
                         repo.all_classes
                       end
                     when "diagrams"
                       # Use all_diagrams when no specific path is provided
                       if path == "ModelRoot"
                         repo.all_diagrams
                       else
                         repo.diagrams_in_package(path)
                       end
                     when "all"
                       list_all_elements(repo, path)
                     else
                       puts OutputFormatter.error(
                         "Unknown type: #{options[:type]}",
                       )
                       raise Thor::Error, "Unknown type: #{options[:type]}"
                     end

          if elements.empty?
            puts OutputFormatter.warning("No #{options[:type]} found")
            return
          end

          display_element_list(elements, options[:type])
        rescue Thor::Error
          raise
        rescue ArgumentError => e
          raise Thor::Error, e.message
        rescue StandardError => e
          raise Thor::Error, "List command failed: #{e.message}"
        end

        private

        def list_all_elements(repo, path)
          elements = []
          elements.concat(repo.list_packages(path || "ModelRoot"))
          elements.concat(repo.classes_in_package(path || "ModelRoot")) if path
          elements.concat(repo.diagrams_in_package(path)) if path
          elements
        end

        def display_element_list(elements, _type)
          output = elements.map { |elem| elem.name || elem.to_s }
          puts OutputFormatter.format(output, format: options[:format])
        end
      end
    end
  end
end
