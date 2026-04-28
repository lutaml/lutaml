# frozen_string_literal: true

require_relative "../../../uml/model_helpers"

module Lutaml
  module UmlRepository
    module StaticSite
      module Serializers
        class PackageTreeBuilder
          include Lutaml::Uml::ModelHelpers

          def initialize(repository, id_generator)
            @repository = repository
            @id_generator = id_generator
          end

          def build
            root_packages = if @repository.document.respond_to?(:packages) &&
                @repository.document.packages
                              @repository.document.packages
                            else
                              @repository.packages_index.select do |pkg|
                                !pkg.respond_to?(:namespace) ||
                                  pkg.namespace.nil? ||
                                  !pkg.namespace.is_a?(Lutaml::Uml::Package)
                              end
                            end

            if root_packages.size == 1
              build_tree_node(root_packages.first)
            else
              {
                id: "root",
                name: "Model",
                path: "",
                classCount: 0,
                children: root_packages.map { |pkg| build_tree_node(pkg) },
              }
            end
          end

          private

          def build_tree_node(package) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
            pkg_id = @id_generator.package_id(package)

            sorted_children = (package.packages || []).sort_by { |p| p.name || "" }
            sorted_classes = (package.classes || [])
              .reject { |c| c.name.nil? || c.name.empty? }
              .sort_by(&:name)

            child_nodes = sorted_children.map { |child| build_tree_node(child) }

            total_class_count = sorted_classes.size + child_nodes.sum { |c| c[:classCount] || 0 }

            {
              id: pkg_id,
              name: package.name,
              path: package_path_for(package),
              stereotypes: normalize_stereotypes(
                package.respond_to?(:stereotype) ? package.stereotype : nil,
              ),
              classCount: total_class_count,
              classes: sorted_classes.map do |c|
                {
                  id: @id_generator.class_id(c),
                  name: c.name,
                  stereotypes: normalize_stereotypes(
                    c.respond_to?(:stereotype) ? c.stereotype : nil,
                  ),
                }
              end,
              children: child_nodes,
            }
          end

          def package_path_for(package)
            unless package.respond_to?(:namespace) && package.namespace
              return package.name
            end
            return package.name unless package.namespace.is_a?(Lutaml::Uml::Package)

            "#{package_path_for(package.namespace)}::#{package.name}"
          end
        end
      end
    end
  end
end
